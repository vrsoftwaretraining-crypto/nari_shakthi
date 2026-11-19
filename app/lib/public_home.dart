// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'search_screen.dart';
import 'theme.dart';

/// What a visitor sees before signing in: profiles without photos. Photos, interests and chat need a sign-in.
class PublicHome extends StatelessWidget {
  final VoidCallback onSignedIn;
  const PublicHome({super.key, required this.onSignedIn});

  void _auth(BuildContext c, bool register) => Navigator.push(c, MaterialPageRoute(builder: (_) => AuthScreen(
        startRegister: register,
        onSignedIn: () {
          Navigator.of(c).popUntil((r) => r.isFirst);
          onSignedIn();
        })));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Nari Shakthi Matrimony', style: TextStyle(fontWeight: FontWeight.w800, color: Palette.plum))),
        body: SearchScreen(onNeedLogin: () => _auth(context, false)),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.95), border: Border(top: BorderSide(color: Palette.marigold.withOpacity(.6)))),
            child: Row(children: [
              Expanded(child: AppButton('Sign in', icon: Icons.login, kind: BtnKind.secondary, onPressed: () => _auth(context, false))),
              const SizedBox(width: 12),
              Expanded(child: AppButton('Create account', icon: Icons.person_add_alt_1, onPressed: () => _auth(context, true))),
            ]),
          ),
        ),
      );
}
