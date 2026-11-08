import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/cloud_config.dart';
import 'database_service.dart';

/// Biashara (business) ambayo kifaa hiki kimeunganishwa nayo.
class CloudBusiness {
  final String id;
  final String name;
  final String role; // 'admin' (kifaa cha kwanza) au 'editor'
  const CloudBusiness({required this.id, required this.name, required this.role});
  bool get isAdmin => role == 'admin';
}

class CloudSyncResult {
  final int uploaded;
  final int downloaded;
  const CloudSyncResult({required this.uploaded, required this.downloaded});
}

/// Namba ya muda ya kuunganisha kifaa kipya (QR + namba ya tarakimu 8).
class LinkCode {
  final String id;
  final String code; // tarakimu 8
  final String token; // siri ndefu ndani ya QR
  final DateTime expiresAt;
  const LinkCode({required this.id, required this.code, required this.token, required this.expiresAt});

  static const qrPrefix = 'RITALICIOUS-LINK:1:';
  String get qrPayload => '$qrPrefix$token';
  String get codeDisplay => code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;
}

/// INVALID = namba si sahihi / imeisha muda, TOO_MANY = majaribio mengi.
class LinkException implements Exception {
  final String code;
  const LinkException(this.code);
  @override
  String toString() => 'LinkException($code)';
}

enum SyncState { off, synced, syncing, offline }

class _CloudLifecycle with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) CloudService.kick(verify: true);
  }
}

/// Usawazishaji wa vifaa kwa wakati halisi (real time).
///
/// Kila kifaa kilichounganishwa ni "peer" kamili: kinatuma mabadiliko yake na
/// kinapokea ya vifaa vingine. Vifaa vinaunganishwa kwa QR au namba ya tarakimu 8
/// (hakuna email/password). Data ya ndani (SQLite) inabaki kuwa chanzo cha kwanza,
/// hivyo app inafanya kazi bila mtandao na inasawazisha mtandao ukipatikana.
class CloudService {
  static bool _initialized = false;
  static SupabaseClient get client => Supabase.instance.client;

  static bool get available => CloudConfig.configured && _initialized;
  static User? get user => available ? client.auth.currentUser : null;

  /// Inaongezeka kila data mpya inapopokelewa kutoka kifaa kingine -> UI ijisasishe.
  static final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);

  /// Inaongezeka orodha ya vifaa inapobadilika (kifaa kipya kimeunganishwa n.k.).
  static final ValueNotifier<int> devicesVersion = ValueNotifier<int>(0);

  /// Inaongezeka kifaa hiki kinapounganishwa au kutenganishwa.
  static final ValueNotifier<int> linkVersion = ValueNotifier<int>(0);

  static final ValueNotifier<SyncState> state = ValueNotifier<SyncState>(SyncState.off);

  static const _kBusinessId = 'rit_business_id';
  static const _kBusinessName = 'rit_business_name';
  static const _kRole = 'rit_role';
  static const _kCursor = 'rit_cursor';
  static const _kDeviceId = 'rit_device_id';

  static DatabaseService get _db => DatabaseService.instance;

  // --------------------------------------------------------------- startup

  static Future<void> initialize() async {
    _db.onLocalChange = () => kick();
    if (!CloudConfig.configured) return;
    try {
      await Supabase.initialize(url: CloudConfig.url, publishableKey: CloudConfig.publishableKey);
      _initialized = true;
    } catch (_) {
      return;
    }
    WidgetsBinding.instance.addObserver(_CloudLifecycle());
    _heartbeat ??= Timer.periodic(const Duration(seconds: 45), (_) {
      if (user != null) unawaited(_safeSync(verify: true));
    });
    if (await cachedBusiness() != null) {
      state.value = SyncState.syncing;
      kick(verify: true);
    }
  }

  static Timer? _heartbeat;
  static Timer? _kickTimer;

  static Future<void> _safeSync({bool verify = false}) async {
    try {
      await sync(verify: verify);
    } catch (_) {}
  }

  /// Anza usawazishaji hivi karibuni (debounce fupi).
  static void kick({bool verify = false, int delayMs = 300}) {
    if (!available) return;
    _kickTimer?.cancel();
    _kickTimer = Timer(Duration(milliseconds: delayMs), () => unawaited(_safeSync(verify: verify)));
  }

  // ----------------------------------------------------------- hali ya kifaa

  static Future<String?> _get(String key) => _db.getSetting(key);

  static Future<String> deviceId() async {
    var id = await _get(_kDeviceId);
    if (id == null || id.length < 16) {
      final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      id = base64UrlEncode(bytes).replaceAll('=', '');
      await _db.setSetting(_kDeviceId, id);
    }
    return id;
  }

  static String defaultDeviceName() {
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isIOS) return 'iPhone';
      if (Platform.isMacOS) return 'Mac';
      if (Platform.isLinux) return 'Linux';
    } catch (_) {}
    return 'Kifaa';
  }

  static String _devName(String? n) {
    final t = (n ?? '').trim();
    final v = t.isEmpty ? defaultDeviceName() : t;
    return v.length > 40 ? v.substring(0, 40) : v;
  }

  /// Biashara iliyohifadhiwa kwenye kifaa (inafanya kazi bila mtandao).
  static Future<CloudBusiness?> cachedBusiness() async {
    final id = await _get(_kBusinessId);
    if (id == null) return null;
    return CloudBusiness(
      id: id,
      name: await _get(_kBusinessName) ?? '',
      role: await _get(_kRole) ?? 'editor',
    );
  }

  static Future<void> _saveBusiness(CloudBusiness b) async {
    await _db.setSetting(_kBusinessId, b.id);
    await _db.setSetting(_kBusinessName, b.name);
    await _db.setSetting(_kRole, b.role);
  }

  static Future<void> _clearBusiness() async {
    final had = await _get(_kBusinessId) != null;
    await _disposeRealtime();
    await _db.setSetting(_kBusinessId, '');
    await _db.setSetting(_kBusinessName, '');
    await _db.setSetting(_kRole, '');
    await _db.setSetting(_kCursor, '');
    state.value = SyncState.off;
    if (had) linkVersion.value++;
  }

  /// Inahakiki kwenye seva kuwa kifaa bado kina ruhusa. null = ruhusa imeondolewa.
  /// Inatupa exception tu kukiwa na tatizo la mtandao.
  static Future<CloudBusiness?> refreshBusiness() async {
    final uid = user?.id;
    if (uid == null) return null;
    final row = await client
        .from('rit_members')
        .select('business_id, role')
        .eq('user_id', uid)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();
    if (row == null) {
      await _clearBusiness();
      return null;
    }
    final id = row['business_id'] as String;
    final b = await client.from('rit_businesses').select('name').eq('id', id).maybeSingle();
    final biz = CloudBusiness(
      id: id,
      name: (b?['name'] as String?) ?? await _get(_kBusinessName) ?? '',
      role: row['role'] as String,
    );
    await _saveBusiness(biz);
    return biz;
  }

  // --------------------------------------------------- kuanzisha / kuunganisha

  static Future<void> _ensureSession() async {
    if (!available) throw StateError('CLOUD_NOT_CONFIGURED');
    if (client.auth.currentSession == null) await client.auth.signInAnonymously();
  }

  /// Kifaa cha KWANZA: kinaunda biashara kwenye wingu na kinakuwa Msimamizi (admin).
  /// Data zote zilizopo kwenye kifaa hiki zitapakiwa.
  static Future<CloudBusiness> createBusiness(String name, {String? deviceName}) async {
    await _ensureSession();
    final res = await client.rpc('rit_create_business', params: {
      'p_name': name.trim(),
      'p_device_id': await deviceId(),
      'p_device_name': _devName(deviceName),
    });
    final m = Map<String, dynamic>.from(res as Map);
    final biz = CloudBusiness(
      id: m['business_id'] as String,
      name: m['business_name'] as String,
      role: m['role'] as String,
    );
    await _db.prepareForNewBusiness();
    await _saveBusiness(biz);
    linkVersion.value++;
    return biz;
  }

  /// Kifaa KIPYA: kinatumia QR (token) au namba ya tarakimu 8.
  static Future<CloudBusiness> redeem(String secret, {String? deviceName, bool wipeLocal = true}) async {
    await _ensureSession();
    var s = secret.trim();
    if (s.startsWith(LinkCode.qrPrefix)) s = s.substring(LinkCode.qrPrefix.length);
    final res = await client.rpc('rit_redeem_pairing_code', params: {
      'p_secret': s,
      'p_device_id': await deviceId(),
      'p_device_name': _devName(deviceName),
    });
    final m = Map<String, dynamic>.from(res as Map);
    if (m['ok'] != true) throw LinkException('${m['error'] ?? 'INVALID'}');
    final biz = CloudBusiness(
      id: m['business_id'] as String,
      name: (m['business_name'] as String?) ?? '',
      role: m['role'] as String,
    );
    await _db.prepareForJoin(wipeLocal: wipeLocal);
    await _saveBusiness(biz);
    dataVersion.value++;
    linkVersion.value++;
    return biz;
  }

  // ------------------------------------------------ msimamizi: vifaa vingine

  static Future<LinkCode> createLinkCode() async {
    final b = await cachedBusiness();
    if (b == null) throw StateError('NO_ACCESS');
    final res = await client.rpc('rit_create_pairing_code', params: {'p_business': b.id});
    final m = Map<String, dynamic>.from(res as Map);
    return LinkCode(
      id: m['id'] as String,
      code: m['code'] as String,
      token: m['token'] as String,
      expiresAt: DateTime.parse(m['expires_at'] as String).toLocal(),
    );
  }

  /// Jina la kifaa kilichotumia namba hii, au null kama bado.
  static Future<String?> linkCodeUsedBy(String id) async {
    final res = await client.rpc('rit_pairing_status', params: {'p_id': id});
    final m = Map<String, dynamic>.from(res as Map);
    if (m['used'] != true) return null;
    return (m['device_name'] as String?) ?? '';
  }

  static Future<List<Map<String, dynamic>>> listDevices() async {
    final b = await cachedBusiness();
    if (b == null) return [];
    final devices = await client
        .from('rit_devices')
        .select('device_id, device_name, user_id, last_seen_at, revoked_at')
        .eq('business_id', b.id)
        .order('last_seen_at', ascending: false);
    final roles = <String, String>{};
    try {
      final members = await client.from('rit_members').select('user_id, role, status').eq('business_id', b.id);
      for (final m in members) {
        roles['${m['user_id']}'] = m['status'] == 'active' ? '${m['role']}' : 'disabled';
      }
    } catch (_) {}
    return [
      for (final d in devices) {...Map<String, dynamic>.from(d), 'role': roles['${d['user_id']}']}
    ];
  }

  static Future<void> revokeDevice(String deviceId) async {
    final b = await cachedBusiness();
    if (b == null) throw StateError('NO_ACCESS');
    await client.rpc('rit_revoke_device', params: {'p_business': b.id, 'p_device_id': deviceId});
    devicesVersion.value++;
  }

  /// Kutenganisha kifaa hiki. Data ya ndani inabaki kwenye kifaa hiki.
  static Future<void> disconnect() async {
    final b = await cachedBusiness();
    if (b != null && user != null) {
      await client.rpc('rit_leave_business', params: {'p_business': b.id, 'p_device_id': await deviceId()});
    }
    try {
      await client.auth.signOut();
    } catch (_) {}
    await _clearBusiness();
  }

  // ------------------------------------------------------------------ sync

  static bool _syncing = false;
  static bool _again = false;
  static bool _againVerify = false;

  static RealtimeChannel? _channel;
  static String? _channelBusiness;
  static Timer? _devicesTimer;

  static Future<void> _ensureRealtime(String businessId) async {
    if (_channelBusiness == businessId && _channel != null) return;
    await _disposeRealtime();
    _channelBusiness = businessId;
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'business_id',
      value: businessId,
    );
    final ch = client.channel('rit-$businessId');
    ch.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'rit_sync_records',
      filter: filter,
      callback: (_) => kick(delayMs: 120),
    );
    ch.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'rit_devices',
      filter: filter,
      callback: (_) {
        _devicesTimer?.cancel();
        _devicesTimer = Timer(const Duration(milliseconds: 800), () => devicesVersion.value++);
      },
    );
    _channel = ch;
    ch.subscribe();
  }

  static Future<void> _disposeRealtime() async {
    final ch = _channel;
    _channel = null;
    _channelBusiness = null;
    try {
      await ch?.unsubscribe();
    } catch (_) {}
  }

  static bool _isNoAccess(Object e) => e.toString().contains('NO_ACCESS');

  /// Inatuma mabadiliko ya ndani kisha inapokea mapya. [verify] pia inahakiki
  /// ruhusa ya kifaa na kusasisha "last seen".
  static Future<CloudSyncResult> sync({bool verify = false}) async {
    const none = CloudSyncResult(uploaded: 0, downloaded: 0);
    if (!available) return none;
    if (_syncing) {
      _again = true;
      _againVerify = _againVerify || verify;
      return none;
    }
    final cached = await cachedBusiness();
    if (cached == null) {
      state.value = SyncState.off;
      return none;
    }
    if (user == null) {
      await _clearBusiness();
      return none;
    }
    _syncing = true;
    state.value = SyncState.syncing;
    try {
      var biz = cached;
      if (verify) {
        final fresh = await refreshBusiness();
        if (fresh == null) return none;
        biz = fresh;
      }
      await _ensureRealtime(biz.id);
      final device = await deviceId();
      if (verify) {
        try {
          await client.rpc('rit_touch_device', params: {
            'p_business': biz.id,
            'p_device_id': device,
            'p_device_name': defaultDeviceName(),
          });
        } catch (_) {}
      }

      // 1) Tuma mabadiliko ya kifaa hiki.
      var uploaded = 0;
      for (var guard = 0; guard < 100; guard++) {
        final rows = await _db.pendingSyncRows(limit: 100);
        if (rows.isEmpty) break;
        await client.rpc('rit_upsert_batch', params: {
          'p_business': biz.id,
          'p_device_id': device,
          'p_rows': rows,
        });
        for (final r in rows) {
          await _db.markPushed(r);
        }
        uploaded += rows.length;
      }

      // 2) Pokea mabadiliko ya vifaa vingine.
      String? cursor = await _get(_kCursor);
      DateTime? maxSynced;
      var downloaded = 0;
      while (true) {
        var q = client.from('rit_sync_records').select().eq('business_id', biz.id);
        if (cursor != null) q = q.gt('synced_at', cursor);
        final rows = await q.order('synced_at', ascending: true).limit(500);
        for (final raw in rows) {
          final r = Map<String, dynamic>.from(raw);
          final applied = await _db.applyRemote(
            entityType: r['entity_type'] as String,
            syncId: r['sync_id'] as String,
            updatedAt: r['updated_at'] as String,
            deleted: r['deleted'] == true,
            payload: Map<String, dynamic>.from((r['payload'] as Map?) ?? const {}),
          );
          if (applied) downloaded++;
          final s = DateTime.tryParse('${r['synced_at']}');
          if (s != null && (maxSynced == null || s.isAfter(maxSynced))) maxSynced = s;
        }
        if (rows.length < 500) break;
        if (maxSynced != null) cursor = maxSynced.toUtc().toIso8601String();
      }
      if (maxSynced != null) {
        // Mwingiliano mdogo (sekunde 3) ili kutopoteza rekodi zilizofika kwa kuchelewa.
        await _db.setSetting(_kCursor, maxSynced.toUtc().subtract(const Duration(seconds: 3)).toIso8601String());
      }

      state.value = SyncState.synced;
      if (downloaded > 0) dataVersion.value++;
      return CloudSyncResult(uploaded: uploaded, downloaded: downloaded);
    } catch (e) {
      if (_isNoAccess(e)) {
        await _clearBusiness();
      } else if (state.value != SyncState.off) {
        state.value = SyncState.offline;
      }
      rethrow;
    } finally {
      _syncing = false;
      if (_again) {
        final v = _againVerify;
        _again = false;
        _againVerify = false;
        kick(verify: v);
      }
    }
  }
}
