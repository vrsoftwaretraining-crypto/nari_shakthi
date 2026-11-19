// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'api.dart';
import 'security_form.dart';
import 'theme.dart';
import 'widgets.dart';

/// The only screen the built-in setup account (admin@test.com) can use: create the real admin.
/// When it succeeds the setup account is disabled by the server and the app signs out.
class SetupAdminScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SetupAdminScreen({super.key, required this.onDone});
  @override
  State<SetupAdminScreen> createState() => _SetupAdminScreenState();
}

class _SetupAdminScreenState extends State<SetupAdminScreen> {
  final _email = TextEditingController(), _pw = TextEditingController(), _pw2 = TextEditingController();
  final _sec = SecurityFormController();
  bool _busy = false, _hide = true;

  Future<void> _create() async {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) return snack(context, 'Enter a valid email address.', error: true);
    if (_pw.text.length < 8) return snack(context, 'Password must be at least 8 characters.', error: true);
    if (_pw.text != _pw2.text) return snack(context, 'The two passwords do not match.', error: true);
    if (!_sec.complete) return snack(context, 'Choose 3 different security questions and answer all of them.', error: true);
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('Create this admin?'),
        content: const Text('After this, the setup account (admin@test.com) is disabled and you will be signed out. Sign in with the new admin account.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Create admin'))]));
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final m = (await Api.call('POST', '/admin/create-admin', body: {'email': _email.text, 'password': _pw.text, 'security': _sec.toJson()}))['message'] as String;
      if (!mounted) return;
      await showDialog(context: context, barrierDismissible: false, builder: (c) => AlertDialog(title: const Text('Admin created'), content: Text(m),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
      widget.onDone();
      return;
    } on ApiError catch (e) {
      if (mounted) snack(context, e.message, error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Palette.blush, borderRadius: BorderRadius.circular(16), border: Border.all(color: Palette.plum.withOpacity(.45), width: 1.4)),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: Palette.plum),
            SizedBox(width: 10),
            Expanded(child: Text('This is the setup account. Its only job is to create the real admin. Once you create it, this setup account is disabled automatically.', style: TextStyle(fontWeight: FontWeight.w600))),
          ]),
        ),
        FormCard('Real admin account', Icons.admin_panel_settings_outlined, [
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Admin email', prefixIcon: Icon(Icons.mail_outline))),
          const SizedBox(height: 14),
          TextField(controller: _pw, obscureText: _hide, decoration: InputDecoration(labelText: 'Password (8+ characters)', prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide)))),
          const SizedBox(height: 14),
          TextField(controller: _pw2, obscureText: _hide, decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_reset_outlined))),
        ]),
        SecurityQuestionsForm(_sec),
        const SizedBox(height: 20),
        AppButton('Create admin and disable setup account', icon: Icons.verified_user_outlined, loading: _busy, onPressed: _create),
        const SizedBox(height: 24),
      ]);
}
