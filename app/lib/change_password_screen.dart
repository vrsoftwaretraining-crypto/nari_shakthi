// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

/// Change password: old password, new password, confirm. Used by admins and members.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _old = TextEditingController(), _new = TextEditingController(), _confirm = TextEditingController();
  String? _eOld, _eNew, _eConfirm;
  bool _hide = true, _busy = false;

  bool _validate() {
    _eOld = _old.text.isEmpty ? 'Enter your old password.' : null;
    _eNew = _new.text.length < 8 ? 'The new password must be at least 8 characters.' : (_new.text == _old.text ? 'The new password must be different from the old one.' : null);
    _eConfirm = _confirm.text != _new.text ? 'The two new passwords do not match.' : null;
    setState(() {});
    return _eOld == null && _eNew == null && _eConfirm == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _busy = true);
    try {
      final m = (await Api.call('POST', '/auth/change-password', body: {'old_password': _old.text, 'new_password': _new.text}))['message'] as String;
      if (!mounted) return;
      snack(context, m);
      Navigator.pop(context);
      return;
    } on ApiError catch (e) {
      if (mounted) snack(context, e.message, error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  InputDecoration _dec(String label, String? err, {bool toggle = false}) => InputDecoration(
        labelText: label, errorText: err, prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: toggle ? IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide)) : null,
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Change password', style: TextStyle(fontWeight: FontWeight.w800, color: Palette.plum))),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FormCard('Update your password', Icons.lock_reset, [
                  TextField(controller: _old, obscureText: _hide, decoration: _dec('Old password', _eOld, toggle: true)),
                  const SizedBox(height: 14),
                  TextField(controller: _new, obscureText: _hide, decoration: _dec('New password (8+ characters)', _eNew)),
                  const SizedBox(height: 14),
                  TextField(controller: _confirm, obscureText: _hide, decoration: _dec('Confirm new password', _eConfirm)),
                ]),
                AppButton('Change password', icon: Icons.check_circle_outline, loading: _busy, onPressed: _save),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ),
      );
}
