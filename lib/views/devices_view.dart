import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import '../core/cloud_config.dart';
import '../services/cloud_service.dart';
import 'link_code_dialog.dart';
import 'link_device_view.dart';

const _brand = Color(0xFF205080);

/// Vifaa & Usawazishaji: kuanzisha biashara kwenye wingu, kuunganisha vifaa
/// vingine (QR / namba ya tarakimu 8) na kuona vifaa vilivyounganishwa.
/// Vifaa vyote vilivyounganishwa vinaona na kuhariri data zilezile kwa wakati halisi.
class DevicesView extends StatefulWidget {
  const DevicesView({super.key});
  @override
  State<DevicesView> createState() => _DevicesViewState();
}

class _DevicesViewState extends State<DevicesView> {
  bool _loading = true;
  bool _busy = false;
  CloudBusiness? _biz;
  List<Map<String, dynamic>> _devices = [];
  String _myDevice = '';
  String? _msg;
  bool _msgOk = false;
  final _bizName = TextEditingController();
  final _devName = TextEditingController(text: CloudService.defaultDeviceName());
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    CloudService.devicesVersion.addListener(_loadDevices);
    CloudService.linkVersion.addListener(_load);
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    CloudService.devicesVersion.removeListener(_loadDevices);
    CloudService.linkVersion.removeListener(_load);
    _clock?.cancel();
    _bizName.dispose();
    _devName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = await CloudService.deviceId();
    var b = await CloudService.cachedBusiness();
    if (b == null && CloudService.available && CloudService.user != null) {
      try {
        b = await CloudService.refreshBusiness(); // kifaa kinaweza kuwa tayari kimeunganishwa upande wa seva
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _myDevice = id;
      _biz = b;
      _loading = false;
      if (b == null) _devices = [];
    });
    if (b == null || !CloudService.available) return;
    _loadDevices();
    try {
      final fresh = await CloudService.refreshBusiness();
      if (mounted) setState(() => _biz = fresh);
      if (fresh != null) CloudService.kick();
    } catch (_) {/* hakuna mtandao: tumia taarifa za ndani */}
  }

  Future<void> _loadDevices() async {
    if (!CloudService.available || CloudService.user == null || _biz == null) return;
    try {
      final l = await CloudService.listDevices();
      if (mounted) setState(() => _devices = l);
    } catch (_) {}
  }

  String _err(Object e) {
    if (e is AuthException) {
      return 'Uingiaji wa kifaa (Anonymous sign-ins) haujawashwa kwenye Supabase. Washa kisha jaribu tena.';
    }
    final s = e.toString();
    if (s.contains('ALREADY_LINKED')) return 'Kifaa hiki tayari kimeunganishwa na biashara. Kitenganishe kwanza.';
    if (s.contains('LAST_ADMIN')) return 'Kifaa cha Msimamizi hakiwezi kujitenga kukiwa na vifaa vingine. Ondoa vifaa vingine kwanza.';
    if (s.contains('ADMIN_ONLY')) return 'Ni kifaa cha Msimamizi pekee kinaweza kufanya hili.';
    if (s.contains('NAME_TOO_SHORT')) return 'Jina la biashara ni fupi mno.';
    if (s.contains('PGRST202') || s.contains('Could not find the function')) {
      return 'Seva haijaandaliwa: endesha faili la SQL (ritalicious_supabase.sql) kwenye Supabase kwanza.';
    }
    return 'Hakuna mtandao au seva haipatikani. Hakikisha una mtandao kisha jaribu tena.';
  }

  void _say(String m, {bool ok = false}) {
    if (!mounted) return;
    setState(() {
      _msg = m;
      _msgOk = ok;
    });
  }

  Future<void> _create() async {
    if (_bizName.text.trim().length < 2) {
      _say('Jina la biashara ni fupi mno.');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await CloudService.createBusiness(_bizName.text, deviceName: _devName.text);
      final r = await CloudService.sync(verify: true); // pakia data zilizopo
      _say('Biashara imeanzishwa. Zimepakiwa rekodi ${r.uploaded}. Sasa unaweza kuongeza vifaa vingine.', ok: true);
      await _load();
    } catch (e) {
      _say(_err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LinkDeviceView()));
    if (ok == true) {
      _say('Kifaa kimeunganishwa. Data za biashara zimepokelewa.', ok: true);
      await _load();
    }
  }

  Future<void> _addDevice() async {
    await showDialog<bool>(context: context, builder: (_) => const LinkCodeDialog());
    _loadDevices();
  }

  Future<void> _syncNow() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final r = await CloudService.sync(verify: true);
      _say('Usawazishaji umekamilika: zilizotumwa ${r.uploaded}, zilizopokelewa ${r.downloaded}.', ok: true);
      await _loadDevices();
    } catch (e) {
      _say(_err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('GHAIRI')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _revoke(Map<String, dynamic> d) async {
    final name = '${d['device_name'] ?? 'Kifaa'}';
    final yes = await _confirm(
      'Ondoa kifaa?',
      'Kifaa "$name" hakitaweza tena kuona wala kuhariri data za biashara. Data zilizo ndani ya kifaa hicho zitabaki huko.',
      'ONDOA',
    );
    if (!yes) return;
    try {
      await CloudService.revokeDevice('${d['device_id']}');
      await _loadDevices();
    } catch (e) {
      _say(_err(e));
    }
  }

  Future<void> _disconnect() async {
    final yes = await _confirm(
      'Tenganisha kifaa hiki?',
      'Kifaa hiki kitaacha kusawazisha na vifaa vingine. Data iliyopo kwenye kifaa hiki itabaki. Ili kuunganisha tena utahitaji namba/QR mpya.${(_biz?.isAdmin ?? false) ? '\n\nKama hiki ndicho kifaa pekee kwenye biashara, nakala ya wingu itafutwa.' : ''}',
      'TENGANISHA',
    );
    if (!yes) return;
    setState(() => _busy = true);
    try {
      await CloudService.disconnect();
      _say('Kifaa kimetenganishwa.', ok: true);
      await _load();
    } catch (e) {
      _say(_err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------------ UI

  bool _online(Map<String, dynamic> d) {
    if (d['revoked_at'] != null) return false;
    final t = DateTime.tryParse('${d['last_seen_at']}');
    if (t == null) return false;
    return DateTime.now().difference(t.toLocal()).inSeconds < 150;
  }

  String _ago(Map<String, dynamic> d) {
    final t = DateTime.tryParse('${d['last_seen_at']}');
    if (t == null) return '';
    final s = DateTime.now().difference(t.toLocal()).inSeconds;
    if (s < 60) return 'sasa hivi';
    if (s < 3600) return 'dakika ${s ~/ 60} zilizopita';
    if (s < 86400) return 'saa ${s ~/ 3600} zilizopita';
    return 'siku ${s ~/ 86400} zilizopita';
  }

  IconData _icon(String name) {
    final n = name.toLowerCase();
    if (n.contains('windows') || n.contains('mac') || n.contains('linux') || n.contains('pc')) return Icons.desktop_windows_outlined;
    return Icons.smartphone;
  }

  Widget _card({required Widget child}) => Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );

  Widget _stateChip() {
    return ValueListenableBuilder<SyncState>(
      valueListenable: CloudService.state,
      builder: (_, s, __) {
        late final String label;
        late final IconData icon;
        late final Color color;
        switch (s) {
          case SyncState.synced:
            label = 'Imesawazishwa';
            icon = Icons.cloud_done_outlined;
            color = Colors.green;
            break;
          case SyncState.syncing:
            label = 'Inasawazisha...';
            icon = Icons.cloud_sync_outlined;
            color = Colors.orange;
            break;
          case SyncState.offline:
            label = 'Hakuna mtandao';
            icon = Icons.cloud_off_outlined;
            color = Colors.red;
            break;
          case SyncState.off:
            label = 'Haijaunganishwa';
            icon = Icons.cloud_off_outlined;
            color = Colors.grey;
            break;
        }
        return Chip(
          avatar: Icon(icon, size: 18, color: color),
          label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }

  List<Widget> _unlinked() => [
        _card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(children: [
              Icon(Icons.cloud_upload_outlined, color: _brand),
              SizedBox(width: 10),
              Expanded(child: Text('Anzisha Biashara kwenye Wingu', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Tumia kifaa hiki kuwa kifaa cha KWANZA (Msimamizi). Data zote zilizopo kwenye kifaa hiki zitapakiwa kwenye wingu, kisha unaweza kuunganisha simu au kompyuta nyingine.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bizName,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Jina la biashara', prefixIcon: Icon(Icons.storefront_outlined)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _devName,
              enabled: !_busy,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Jina la kifaa hiki', prefixIcon: Icon(Icons.devices_outlined), counterText: ''),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload),
              label: const Text('ANZISHA NA PAKIA DATA'),
            ),
          ]),
        ),
        _card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(children: [
              Icon(Icons.link, color: _brand),
              SizedBox(width: 10),
              Expanded(child: Text('Unganisha na Biashara Iliyopo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Kama biashara tayari imeanzishwa kwenye kifaa kingine, changanua QR au weka namba ya tarakimu 8. Kifaa hiki kitaona na kuhariri data zilezile.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _join,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('UNGANISHA KIFAA HIKI'),
            ),
          ]),
        ),
      ];

  List<Widget> _linked() {
    final b = _biz!;
    return [
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.storefront, color: _brand, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.name.isEmpty ? 'Biashara' : b.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text(b.isAdmin ? 'Kifaa hiki: Msimamizi' : 'Kifaa hiki: Mwanachama', style: const TextStyle(color: Colors.black54)),
              ]),
            ),
            _stateChip(),
          ]),
          const SizedBox(height: 10),
          const Text(
            'Vifaa vyote vilivyounganishwa vinaona na kuhariri data zilezile (Sales, Expenses, Inventory, Rekodi) kwa wakati halisi. Bila mtandao, kazi inaendelea na inasawazishwa mtandao ukirudi.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _syncNow,
              icon: const Icon(Icons.sync),
              label: const Text('SAWAZISHA SASA'),
            ),
            if (b.isAdmin)
              FilledButton.icon(
                onPressed: _busy ? null : _addDevice,
                icon: const Icon(Icons.add_link),
                label: const Text('ONGEZA KIFAA KIPYA'),
              ),
          ]),
        ]),
      ),
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Vifaa vilivyounganishwa (${_devices.where((d) => d['revoked_at'] == null).length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (_devices.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Hakuna vifaa vinavyoonekana bado.', style: TextStyle(color: Colors.black54))),
          for (final d in _devices) _deviceTile(d, b),
        ]),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _busy ? null : _disconnect,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          icon: const Icon(Icons.link_off),
          label: const Text('Tenganisha kifaa hiki'),
        ),
      ),
    ];
  }

  Widget _deviceTile(Map<String, dynamic> d, CloudBusiness b) {
    final name = '${d['device_name'] ?? 'Kifaa'}';
    final revoked = d['revoked_at'] != null || d['role'] == 'disabled';
    final mine = '${d['device_id']}' == _myDevice;
    final online = !revoked && (mine || _online(d));
    final role = d['role'] == 'admin' ? 'Msimamizi' : 'Mwanachama';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Stack(clipBehavior: Clip.none, children: [
        Icon(_icon(name), size: 30, color: revoked ? Colors.grey : _brand),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: online ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ]),
      title: Text(mine ? '$name (kifaa hiki)' : name, style: TextStyle(fontWeight: FontWeight.w700, decoration: revoked ? TextDecoration.lineThrough : null)),
      subtitle: Text(revoked ? 'Ufikiaji umeondolewa' : '$role • ${online ? 'Online' : 'Mara ya mwisho: ${_ago(d)}'}'),
      trailing: (b.isAdmin && !mine && !revoked)
          ? IconButton(
              tooltip: 'Ondoa kifaa',
              icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
              onPressed: _busy ? null : () => _revoke(d),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (!CloudConfig.configured)
        _card(
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Huduma ya wingu haijawekwa kwenye toleo hili la programu. Weka SUPABASE_URL na SUPABASE_PUBLISHABLE_KEY kwenye GitHub Secrets kisha jenga toleo jipya.',
              ),
            ),
          ]),
        )
      else if (_biz == null)
        ..._unlinked()
      else
        ..._linked(),
      if (_msg != null)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: Text(_msg!, style: TextStyle(color: _msgOk ? Colors.green.shade800 : Colors.red.shade700, fontWeight: FontWeight.w700)),
        ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vifaa & Usawazishaji'),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(padding: const EdgeInsets.all(14), children: children),
              ),
            ),
    );
  }
}
