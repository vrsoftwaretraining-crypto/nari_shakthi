// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

/// Forgot password: enter email, answer the 3 security questions chosen at sign-up, set a new password.
class ResetScreen extends StatefulWidget {
  const ResetScreen({super.key});
  @override
  State<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends State<ResetScreen> {
  final _email = TextEditingController(), _pw = TextEditingController(), _pw2 = TextEditingController();
  final _ans = List.generate(3, (_) => TextEditingController());
  List<Map<String, dynamic>>? _qs;
  bool _busy = false, _hide = true;
  String? _err;

  Future<void> _getQuestions() async {
    if (_email.text.trim().isEmpty) return setState(() => _err = 'Enter your email address.');
    setState(() { _busy = true; _err = null; });
    try {
      final d = await Api.call('POST', '/auth/recover/questions', body: {'email': _email.text});
      _qs = (d['questions'] as List).cast<Map<String, dynamic>>();
    } on ApiError catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reset() async {
    if (_ans.any((c) => c.text.trim().isEmpty)) return setState(() => _err = 'Answer all 3 questions.');
    if (_pw.text.length < 8) return setState(() => _err = 'New password must be at least 8 characters.');
    if (_pw.text != _pw2.text) return setState(() => _err = 'The two passwords do not match.');
    setState(() { _busy = true; _err = null; });
    try {
      final d = await Api.call('POST', '/auth/recover/reset', body: {'email': _email.text, 'answers': [for (final c in _ans) c.text], 'password': _pw.text});
      if (!mounted) return;
      snack(context, d['message'] as String);
      Navigator.pop(context);
      return;
    } on ApiError catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Forgot password', style: TextStyle(fontWeight: FontWeight.w800, color: Palette.plum))),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  FormCard('Step 1: your account', Icons.mail_outline, [
                    TextField(controller: _email, enabled: _qs == null, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Your email', prefixIcon: Icon(Icons.mail_outline))),
                    if (_qs == null) ...[
                      const SizedBox(height: 14),
                      AppButton('Show my security questions', icon: Icons.arrow_forward, loading: _busy, onPressed: _getQuestions),
                    ] else ...[
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() { _qs = null; _err = null; }), icon: const Icon(Icons.edit_outlined), label: const Text('Change email'))),
                    ],
                  ]),
                  if (_qs != null) ...[
                    FormCard('Step 2: answer your 3 questions', Icons.shield_outlined, [
                      for (var i = 0; i < 3; i++) ...[
                        Text(_qs![i]['text'] as String, style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.plumDeep)),
                        const SizedBox(height: 8),
                        TextField(controller: _ans[i], decoration: InputDecoration(labelText: 'Answer ${i + 1}', prefixIcon: const Icon(Icons.key_outlined))),
                        const SizedBox(height: 16),
                      ],
                    ]),
                    FormCard('Step 3: new password', Icons.lock_reset_outlined, [
                      TextField(controller: _pw, obscureText: _hide, decoration: InputDecoration(labelText: 'New password (8+ characters)', prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide)))),
                      const SizedBox(height: 14),
                      TextField(controller: _pw2, obscureText: _hide, decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.lock_outline))),
                    ]),
                  ],
                  if (_err != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_err!, style: const TextStyle(color: Palette.crimson, fontWeight: FontWeight.w700))),
                  if (_qs != null) AppButton('Change password', icon: Icons.check_circle_outline, loading: _busy, onPressed: _reset),
                ]),
              ),
            ),
          ),
        ),
      );
}
