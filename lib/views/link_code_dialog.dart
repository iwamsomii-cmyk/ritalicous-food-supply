import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/cloud_service.dart';

/// Kifaa cha Msimamizi kinaonyesha QR + namba ya tarakimu 8 ya kuunganisha kifaa kipya.
class LinkCodeDialog extends StatefulWidget {
  const LinkCodeDialog({super.key});
  @override
  State<LinkCodeDialog> createState() => _LinkCodeDialogState();
}

class _LinkCodeDialogState extends State<LinkCodeDialog> {
  LinkCode? _code;
  bool _busy = false;
  String? _error;
  String? _usedBy; // jina la kifaa kilichounganishwa
  Timer? _tick;
  int _polls = 0;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _secondsLeft => _code == null ? 0 : _code!.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 3600).toInt();
  bool get _expired => _code != null && _usedBy == null && _secondsLeft == 0;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
      _usedBy = null;
    });
    try {
      final c = await CloudService.createLinkCode();
      _tick?.cancel();
      _polls = 0;
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
      if (mounted) setState(() => _code = c);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().contains('ADMIN_ONLY')
            ? 'Ni kifaa cha Msimamizi pekee kinaweza kuongeza vifaa vipya.'
            : 'Hakuna mtandao au seva haipatikani. Jaribu tena.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onTick() async {
    if (!mounted || _code == null) return;
    if (_usedBy != null || _secondsLeft == 0) {
      _tick?.cancel();
      setState(() {});
      return;
    }
    setState(() {}); // sasisha countdown
    _polls++;
    if (_polls % 2 == 0) {
      try {
        final used = await CloudService.linkCodeUsedBy(_code!.id);
        if (used != null && mounted) {
          _tick?.cancel();
          setState(() => _usedBy = used);
          CloudService.devicesVersion.value++;
        }
      } catch (_) {}
    }
  }

  String _mmss(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final active = _code != null && _usedBy == null && !_expired;
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.qr_code_2, color: Color(0xFF205080)),
        SizedBox(width: 10),
        Expanded(child: Text('Ongeza Kifaa Kipya')),
      ]),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text(
              'Kwenye kifaa kipya fungua Ritalicious > menu > "Vifaa & Usawazishaji" > "Unganisha na Biashara", kisha changanua QR hii au weka namba ya tarakimu 8.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            if (_busy && _code == null)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_usedBy != null) ...[
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 8),
              Text(
                _usedBy!.isEmpty ? 'Kifaa kimeunganishwa.' : 'Kifaa kimeunganishwa: $_usedBy',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ] else if (active) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: QrImageView(data: _code!.qrPayload, version: QrVersions.auto, size: 210, backgroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: InkWell(
                  onTap: () => Clipboard.setData(ClipboardData(text: _code!.code)),
                  child: Text(
                    _code!.codeDisplay,
                    style: const TextStyle(fontSize: 34, letterSpacing: 4, fontWeight: FontWeight.w900, color: Color(0xFF205080)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text('Inaisha baada ya ${_mmss(_secondsLeft)}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.teal)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Namba hii inatumika mara moja tu. Usimpe mtu usiyemwamini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 12.5),
              ),
            ] else ...[
              if (_expired)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text('Namba hii imeisha muda. Tengeneza nyingine.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                ),
              FilledButton.icon(
                onPressed: _busy ? null : _generate,
                icon: const Icon(Icons.qr_code),
                label: const Text('TENGENEZA NAMBA'),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ]),
        ),
      ),
      actions: [
        if (active) TextButton(onPressed: _busy ? null : _generate, child: const Text('TENGENEZA UPYA')),
        TextButton(onPressed: () => Navigator.pop(context, _usedBy != null), child: const Text('FUNGA')),
      ],
    );
  }
}
