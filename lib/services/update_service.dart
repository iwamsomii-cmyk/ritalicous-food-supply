import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Build number of the running app. CI passes --dart-define=BUILD_NUMBER=<n>;
/// 0 means a developer build (updates are skipped).
const int kBuildNumber = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);

class UpdateInfo {
  final int build;
  final String version;
  final String url;
  final String fileName;
  const UpdateInfo(this.build, this.version, this.url, this.fileName);
}

/// Checks GitHub Releases for a newer build and installs it.
/// Everything fails silently when there is no internet, so the app keeps
/// working fully offline.
class UpdateService {
  static const _base =
      'https://github.com/iwamsomii-cmyk/ritalicous-food-supply/releases/download/latest';
  static const _channel = MethodChannel('ritalicious/updater');

  static Future<UpdateInfo?> check() async {
    if (kBuildNumber == 0) return null;
    if (!(Platform.isAndroid || Platform.isWindows)) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client
          .getUrl(Uri.parse('$_base/version.json'))
          .timeout(const Duration(seconds: 8));
      req.headers.set('Cache-Control', 'no-cache');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 8));
      final j = jsonDecode(body) as Map<String, dynamic>;
      final build = (j['build'] as num).toInt();
      if (build <= kBuildNumber) return null;
      final name = Platform.isAndroid
          ? 'Ritalicious-Food-Supply.apk'
          : 'Ritalicious-Food-Supply-Setup.exe';
      return UpdateInfo(build, '${j['version']}', '$_base/$name', name);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<File> download(
      UpdateInfo info, void Function(double? progress) onProgress) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, info.fileName));
    if (await file.exists()) await file.delete();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(info.url));
      final res = await req.close();
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      final total = res.contentLength;
      var got = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in res) {
          got += chunk.length;
          sink.add(chunk);
          onProgress(total > 0 ? got / total : null);
        }
      } finally {
        await sink.close();
      }
      if (total > 0 && got != total) throw const HttpException('Incomplete download');
      return file;
    } finally {
      client.close(force: true);
    }
  }

  /// Returns false when the user still has to allow installs (Android).
  static Future<bool> install(File file) async {
    if (Platform.isWindows) {
      await Process.start(
        file.path,
        ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS'],
        mode: ProcessStartMode.detached,
      );
      exit(0); // installer replaces the files and re-opens the app
    }
    if (Platform.isAndroid) {
      final can = await _channel.invokeMethod<bool>('canInstall') ?? false;
      if (!can) {
        await _channel.invokeMethod('openInstallSettings');
        return false;
      }
      await _channel.invokeMethod('install', {'path': file.path});
      return true;
    }
    return false;
  }
}
