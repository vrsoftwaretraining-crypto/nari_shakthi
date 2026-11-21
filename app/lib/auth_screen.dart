// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'api.dart';
import 'form_dialog.dart';
import 'reset_screen.dart';
import 'security_form.dart';
import 'theme.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onSignedIn;
  final bool startRegister;
  final VoidCallback? onClose; // set when shown inside the website's centred dialog
  const AuthScreen({super.key, required this.onSignedIn, this.startRegister = false, this.onClose});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController(), _pw = TextEditingController(), _pw2 = TextEditingController();
  final _sec = SecurityFormController();
  late bool _register = widget.startRegister;
  bool _busy = false, _hide = true, _confirm = false;
  String? _msg;
  bool _isError = false;
  bool get _embedded => widget.onClose != null;

  void _fail(String m) => setState(() { _isError = true; _msg = m; });

  Future<void> _submit() async {
    if (_register) {
      if (_pw.text.length < 8) return _fail('Password must be at least 8 characters.');
      if (_pw.text != _pw2.text) return _fail('The two passwords do not match.');
      if (!_sec.complete) return _fail('Please choose 3 different security questions and answer all of them.');
    }
    setState(() { _busy = true; _msg = null; });
    try {
      final d = await Api.call('POST', '/auth/${_register ? 'register' : 'login'}', body: {
        'email': _email.text, 'password': _pw.text,
        if (_register) ...{'confirm_second_marriage': _confirm, 'security': _sec.toJson()},
      });
      if (_register) {
        setState(() { _register = false; _isError = false; _msg = 'Account created. Sign in to continue.'; _pw2.clear(); });
      } else {
        await Api.save(d['token'] as String, d['role'] as String);
        widget.onSignedIn();
      }
    } on ApiError catch (e) {
      _fail(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _brand() => Column(children: [
        Text('Nari Shakthi', textAlign: TextAlign.center,
            style: TextStyle(fontFamily: kSerif, fontVariations: kSerifBold, fontSize: 42, fontWeight: FontWeight.w800, color: Palette.plumDeep, height: 1.05,
                shadows: [Shadow(color: Colors.white.withOpacity(.9), blurRadius: 10)])),
        const SizedBox(height: 4),
        const Text('MATRIMONY', style: TextStyle(fontSize: 16, letterSpacing: 9, fontWeight: FontWeight.w700, color: Color(0xFFB07A10))),
        const SizedBox(height: 12),
        Container(height: 2.5, width: 70, decoration: BoxDecoration(color: Palette.marigold, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        const Text('Exclusively for second marriages', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.plum)),
        const SizedBox(height: 4),
        const Text('Divorced  •  Widowed  •  Legally Separated', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: Colors.black54)),
      ]);

  @override
  Widget build(BuildContext context) {
    final top = (MediaQuery.of(context).size.height * .20).clamp(60.0, 200.0);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: !_embedded && Navigator.canPop(context) ? AppBar(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, iconTheme: const IconThemeData(color: Palette.plumDeep)) : null,
      body: Stack(fit: StackFit.expand, children: [
        AppBackground(
        image: 'assets/images/login_bg.jpg',
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, _embedded ? 44 : top - 40, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _brand(),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.94), borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: Palette.marigold.withOpacity(.7), width: 1.6),
                        boxShadow: [BoxShadow(color: Palette.plum.withOpacity(.15), blurRadius: 24, offset: const Offset(0, 10))]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(_register ? 'Create your account' : 'Welcome back', textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Palette.plumDeep)),
                      const SizedBox(height: 16),
                      TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline))),
                      const SizedBox(height: 14),
                      TextField(controller: _pw, obscureText: _hide, decoration: InputDecoration(labelText: 'Password (8+ characters)', prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide)))),
                      if (_register) ...[
                        const SizedBox(height: 14),
                        TextField(controller: _pw2, obscureText: _hide, decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_reset_outlined))),
                        const SizedBox(height: 16),
                        SecurityQuestionsForm(_sec),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: _confirm, onChanged: (v) => setState(() => _confirm = v ?? false), contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading, activeColor: Palette.plum,
                          title: const Text('I am Divorced, Widowed or Legally Separated, and I am looking for a second marriage.', style: TextStyle(fontSize: 13.5)),
                        ),
                      ],
                      if (_msg != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_msg!, style: TextStyle(color: _isError ? Palette.crimson : Palette.plum, fontWeight: FontWeight.w600))),
                      const SizedBox(height: 18),
                      AppButton(_register ? 'Create account' : 'Sign in', icon: _register ? Icons.person_add_alt_1 : Icons.login, loading: _busy,
                          onPressed: _register && !_confirm ? null : _submit),
                      const SizedBox(height: 12),
                      AppButton(_register ? 'I already have an account' : 'Create a new account', kind: BtnKind.secondary,
                          onPressed: () => setState(() { _register = !_register; _msg = null; })),
                      if (!_register)
                        TextButton(
                          onPressed: () {
                            if (_embedded) {
                              showFormDialog(context, (close) => const ResetScreen());
                            } else {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetScreen()));
                            }
                          },
                          child: const Text('Forgot password?')),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
        if (_embedded) Positioned(top: 8, right: 8, child: IconButton(tooltip: 'Close', icon: const Icon(Icons.close, color: Palette.plumDeep), onPressed: widget.onClose)),
      ]),
    );
  }
}
