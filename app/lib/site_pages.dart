// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'site_widgets.dart';
import 'stories.dart';
import 'theme.dart';
import 'widgets.dart';

/// Three-column grid that adapts to the available width.
Widget _grid(List<Widget> items, {int columns = 3, double gap = 28}) => LayoutBuilder(builder: (c, box) {
      final w = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: gap, children: [for (final i in items) SizedBox(width: w, child: i)]);
    });

Widget _para(String t) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(t, style: const TextStyle(fontSize: 17, height: 1.7, color: Colors.black87)));

Widget _ctaBand(String title, String sub, List<Widget> buttons) => Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 32),
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.plumDeep, Palette.plum, Palette.crimson])),
      child: Column(children: [
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: kSerif, fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 12),
        Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.white70)),
        const SizedBox(height: 28),
        Wrap(spacing: 16, runSpacing: 12, alignment: WrapAlignment.center, children: buttons),
      ]),
    );

/// About us: what Nari Shakthi Matrimony is and who it is for.
class AboutPage extends StatelessWidget {
  final VoidCallback onRegister, onSearch;
  const AboutPage({super.key, required this.onRegister, required this.onSearch});

  @override
  Widget build(BuildContext context) => Column(children: [
        const PageBanner('About Nari Shakthi Matrimony', 'A social-service introduction platform, a parichaya vedika, for people who are starting life again.', 'assets/web/hero.jpg'),
        SiteSection(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 6,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SiteHeading('Our purpose', 'Why Nari Shakthi exists', center: false),
                const SizedBox(height: 24),
                _para('Nari Shakthi Matrimony is a social-service matrimony and introduction platform, a parichaya vedika, created for men and women who are rebuilding their lives after divorce, widowhood or legal separation.'),
                _para('Such moments change everything. Many people carry loneliness, the weight of other people\u2019s opinions and the fear of being judged. Finding a respectful new beginning can feel almost impossible. Nari Shakthi exists to give them a safe and dignified place where they can meet people who truly understand.'),
                _para('Our purpose is simple: to help every person move from a painful past to a peaceful, happy and fulfilling future, and to give them the confidence that a second chance at love is something to be proud of.'),
              ]),
            ),
            const SizedBox(width: 56),
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.plum, Palette.crimson]), borderRadius: BorderRadius.circular(26),
                    boxShadow: [BoxShadow(color: Palette.plum.withOpacity(.25), blurRadius: 30, offset: const Offset(0, 14))]),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.format_quote, size: 48, color: Palette.marigold),
                  SizedBox(height: 8),
                  Text('Every person deserves a second chance at a happy, peaceful life.', style: TextStyle(fontFamily: kSerif, fontSize: 28, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, color: Colors.white, height: 1.35)),
                ]),
              ),
            ),
          ]),
        ),
        SiteSection(
          color: Palette.mist,
          child: Column(children: [
            const SiteHeading('Who we serve', 'A place for every new beginning', sub: 'Single parents and families are welcome too. We understand that children are at the heart of many second marriages.'),
            const SizedBox(height: 44),
            _grid(const [
              FeatureCard(Icons.autorenew, 'Divorced', 'Men and women who have ended a marriage and are ready to build a new, happier chapter with someone who respects their journey.'),
              FeatureCard(Icons.spa_outlined, 'Widowed', 'People who lost a life partner and wish to find companionship again, honouring the past while welcoming the future.'),
              FeatureCard(Icons.balance, 'Legally separated', 'People who are living apart and want a fresh start built on honesty, clarity and mutual respect.'),
            ]),
          ]),
        ),
        SiteSection(
          child: Column(children: [
            const SiteHeading('What we stand for', 'Dignity, privacy, consent and safety'),
            const SizedBox(height: 44),
            _grid(const [
              FeatureCard(Icons.favorite_border, 'Dignity', 'Every member is treated with respect, whatever their past.'),
              FeatureCard(Icons.lock_outline, 'Privacy', 'Photos stay private. You choose who is allowed to see them.'),
              FeatureCard(Icons.verified_user_outlined, 'Consent', 'Chat opens only after both people agree to talk.'),
              FeatureCard(Icons.shield_outlined, 'Safety', 'Profiles are reviewed by an admin, and any member can report or block.'),
            ], columns: 4, gap: 24),
          ]),
        ),
        _ctaBand('Your next chapter can begin today', 'Create a free profile, or look through profiles first.', [
          SitePill('Register free', icon: Icons.person_add_alt_1, onTap: onRegister),
          SitePill('Search profiles', icon: Icons.search, filled: false, onTap: onSearch),
        ]),
      ]);
}

class StoriesPage extends StatelessWidget {
  final VoidCallback onRegister;
  const StoriesPage({super.key, required this.onRegister});

  @override
  Widget build(BuildContext context) => Column(children: [
        const PageBanner('Success stories', 'Stories of hope and new beginnings, from people who found happiness again.', 'assets/web/story3.jpg'),
        SiteSection(child: _grid([for (final s in successStories) StoryCard(s)])),
        _ctaBand('Your story can be next', 'Join Nari Shakthi and meet someone who understands.', [SitePill('Register free', icon: Icons.person_add_alt_1, onTap: onRegister)]),
      ]);
}

/// Donate: anyone can donate, no login. Shows the QR code and UPI ID the admin saved.
class DonatePage extends StatefulWidget {
  const DonatePage({super.key});
  @override
  State<DonatePage> createState() => _DonatePageState();
}

class _DonatePageState extends State<DonatePage> {
  Map<String, dynamic>? _d;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _d = await Api.call('GET', '/public/donate');
      _err = null;
    } on ApiError catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() {});
  }

  Widget _tick(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle, color: Palette.plum, size: 22), const SizedBox(width: 12), Expanded(child: Text(t, style: const TextStyle(fontSize: 16.5, height: 1.5)))]));

  Widget _qrCard() {
    final d = _d;
    final upi = d?['upi_id'] as String?, name = d?['payee_name'] as String?, hasQr = d?['has_qr'] == true;
    Widget body;
    if (d == null) {
      body = _err == null ? const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()) : Padding(padding: const EdgeInsets.all(20), child: Text(_err!, textAlign: TextAlign.center));
    } else if (!hasQr && upi == null) {
      body = const Padding(padding: EdgeInsets.all(24), child: Text('Donation details will be available soon. Thank you for your kindness.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.5)));
    } else {
      body = Column(children: [
        if (hasQr) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Palette.plum.withOpacity(.25), width: 1.4)),
            child: Image.network('$apiBase/public/donate/qr?v=${d['version']}', height: 280, width: 280, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(height: 280, width: 280, child: Center(child: Text('Could not load the QR code.'))))),
        if (name != null) Padding(padding: const EdgeInsets.only(top: 18), child: Text(name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Palette.plumDeep))),
        if (upi != null) Container(
          margin: const EdgeInsets.only(top: 14), padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
          decoration: BoxDecoration(color: Palette.mist, borderRadius: BorderRadius.circular(14), border: Border.all(color: Palette.plum.withOpacity(.4), width: 1.2)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SelectableText(upi, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            IconButton(tooltip: 'Copy UPI ID', icon: const Icon(Icons.copy, size: 20), onPressed: () { Clipboard.setData(ClipboardData(text: upi)); snack(context, 'UPI ID copied.'); }),
          ]),
        ),
      ]);
    }
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: Palette.plum.withOpacity(.14)),
          boxShadow: [BoxShadow(color: Palette.plum.withOpacity(.12), blurRadius: 34, offset: const Offset(0, 14))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Scan to donate', style: TextStyle(fontFamily: kSerif, fontSize: 26, fontWeight: FontWeight.w800, color: Palette.plumDeep)),
        const SizedBox(height: 6),
        const Text('Use any UPI app', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 20),
        body,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        const PageBanner('Donate', 'Your kindness helps someone begin again.', 'assets/web/story2.jpg'),
        SiteSection(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SiteHeading('Support our mission', 'Help a family start again', center: false),
                const SizedBox(height: 24),
                _para('Every contribution, big or small, helps keep Nari Shakthi safe, respectful and available to people who are rebuilding their lives after divorce or the loss of a spouse.'),
                const SizedBox(height: 6),
                _tick('Anyone can donate. No account or login is needed.'),
                _tick('Scan the QR code with Google Pay, PhonePe, Paytm, BHIM or any UPI app.'),
                _tick('Donating is entirely voluntary and does not give any membership benefit.'),
              ]),
            ),
            const SizedBox(width: 56),
            SizedBox(width: 420, child: _qrCard()),
          ]),
        ),
      ]);
}
