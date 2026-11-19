// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'api.dart';
import 'home.dart';
import 'public_home.dart';
import 'theme.dart';
import 'landing_page.dart';
import 'web_shell.dart';

void main() => runApp(const NariShakthiApp());

class NariShakthiApp extends StatelessWidget {
  const NariShakthiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Nari Shakthi Matrimony', debugShowCheckedModeBanner: false, theme: appTheme(),
        builder: (c, child) => ValueListenableBuilder<int>(valueListenable: Api.session, builder: (_, __, ___) => AdaptiveFrame(child: child!)),
        home: const Root(),
      );
}

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    Api.signedOut.addListener(() { if (mounted) setState(() {}); });
    Api.restore().then((_) => setState(() => _ready = true));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    // Wide screens = the website. Phones and narrow windows keep the app layout.
    final wide = MediaQuery.of(context).size.width >= AdaptiveFrame.breakpoint;
    if (Api.token == null) {
      return wide ? LandingPage(onSignedIn: () => setState(() {})) : PublicHome(onSignedIn: () => setState(() {}));
    }
    return Home(onSignedOut: () async { await Api.signOut(); setState(() {}); });
  }
}
