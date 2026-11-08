import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import '../services/cloud_service.dart';

/// Kifaa KIPYA kinaunganishwa na biashara iliyopo kwa QR au namba ya tarakimu 8.
/// Inarudisha `true` (Navigator.pop) baada ya kuunganishwa na data kupokelewa.
class LinkDeviceView extends StatefulWidget {
  const LinkDeviceView({super.key});
  @override
  State<LinkDeviceView> createState() => _LinkDeviceViewState();
}

class _LinkDeviceViewState extends State<LinkDeviceView> {
  final _name = TextEditingController(text: CloudService.defaultDeviceName());
  final _otp = TextEditingController();
  MobileScannerController? _scanner;
  bool _busy = false;
  bool _wipe = true;
  String? _error;
  String? _lastFailedQr;

  bool get _canScan => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (_canScan) _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  }

  @override
  void dispose() {
    _scanner?.dispose();
    _name.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _link(String secret, {String? qr}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CloudService.redeem(secret, deviceName: _name.text, wipeLocal: _wipe);
      try {
        await CloudService.sync(verify: true); // pokea data zote za biashara mara moja
      } catch (_) {/* usawazishaji wa kawaida utajaribu tena */}
      if (!mounted) return;
      Navigator.pop(context, true);
    } on LinkException catch (e) {
      _lastFailedQr = qr;
      if (mounted) {
        setState(() => _error = e.code == 'TOO_MANY'
            ? 'Majaribio mengi mno yasiyo sahihi. Subiri dakika chache kisha jaribu tena.'
            : 'Namba si sahihi au imeisha muda. Hakikisha kisha jaribu tena.');
      }
    } on AuthException catch (_) {
      if (mounted) {
        setState(() => _error = 'Uingiaji wa kifaa (Anonymous sign-ins) haujawashwa kwenye Supabase. Wasiliana na msimamizi wa mfumo.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Hakuna mtandao au seva haipatikani. Hakikisha una mtandao kisha jaribu tena.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.startsWith(LinkCode.qrPrefix) && v != _lastFailedQr) {
        _link(v, qr: v);
        return;
      }
    }
  }

  void _submitOtp() {
    final code = _otp.text.trim();
    if (code.length != 8) {
      setState(() => _error = 'Weka namba kamili ya tarakimu 8.');
      return;
    }
    _link(code);
  }

  Widget _scanTab() {
    if (!_canScan) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Kuchanganua QR hakupatikani kwenye kifaa hiki. Tumia namba ya tarakimu 8.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
        ),
      );
    }
    return Column(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(color: Colors.black, child: MobileScanner(controller: _scanner!, onDetect: _onDetect)),
        ),
      ),
      const SizedBox(height: 10),
      const Text('Elekeza kamera kwenye QR inayoonyeshwa kwenye kifaa cha Msimamizi.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12.5)),
    ]);
  }

  Widget _otpTab() => SingleChildScrollView(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Weka namba ya tarakimu 8 inayoonyeshwa kwenye kifaa cha Msimamizi.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 14),
          TextField(
            controller: _otp,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            maxLength: 8,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 6, fontWeight: FontWeight.w800, color: Color(0xFF205080)),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Namba ya tarakimu 8', counterText: ''),
            onSubmitted: (_) => _submitOtp(),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : _submitOtp,
            icon: const Icon(Icons.link),
            label: const Text('UNGANISHA'),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      if (_canScan) const Tab(icon: Icon(Icons.qr_code_scanner), text: 'Changanua QR'),
      const Tab(icon: Icon(Icons.pin_outlined), text: 'Weka namba'),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(title: const Text('Unganisha Kifaa Hiki')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  TextField(
                    controller: _name,
                    maxLength: 40,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: 'Jina la kifaa hiki', prefixIcon: Icon(Icons.devices_outlined), counterText: ''),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _wipe,
                    onChanged: _busy ? null : (v) => setState(() => _wipe = v ?? true),
                    title: const Text('Futa data za sasa za kifaa hiki kwanza', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Inapendekezwa: kifaa kitaonyesha data za biashara pekee. Ukiondoa tiki, data za kifaa hiki zitaunganishwa na za biashara.', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 4),
                  TabBar(tabs: tabs),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [if (_canScan) _scanTab(), _otpTab()],
                    ),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Inaunganisha na kupokea data za biashara...'),
                      ]),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
