// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'form_dialog.dart';
import 'search_screen.dart';
import 'site_pages.dart';
import 'site_widgets.dart';
import 'stories.dart';
import 'theme.dart';

/// The public website (wide screens, signed out): Home, About us, Success stories, Donate.
/// Sign in, Register and Search open as centred, fixed-size forms.
class LandingPage extends StatefulWidget {
  final VoidCallback onSignedIn;
  const LandingPage({super.key, required this.onSignedIn});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _scroll = ScrollController();
  String _tab = 'home';
  bool _solid = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final s = _scroll.hasClients && _scroll.offset > 60;
      if (s != _solid) setState(() => _solid = s);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(String tab) {
    setState(() => _tab = tab);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _auth([bool register = false]) => showFormDialog(context, (close) => AuthScreen(
      startRegister: register, onClose: close,
      onSignedIn: () {
        close();
        widget.onSignedIn();
      }));

  void _search() => showFormDialog(context, (close) => _SearchDialog(onClose: close, onNeedLogin: () {
        close();
        _auth();
      }));

  Widget _nav() {
    final fg = _solid ? Palette.plumDeep : Colors.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250), height: 78, padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: _solid ? Colors.white.withOpacity(.96) : Colors.transparent,
        border: _solid ? Border(bottom: BorderSide(color: Palette.marigold.withOpacity(.5), width: 2)) : null,
        boxShadow: _solid ? [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 20, offset: const Offset(0, 6))] : null,
      ),
      child: Row(children: [
        InkWell(
          onTap: () => _go('home'),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Palette.marigold, Palette.crimson]),
                  boxShadow: [BoxShadow(color: Palette.crimson.withOpacity(.35), blurRadius: 12, offset: const Offset(0, 4))]),
              child: const Icon(Icons.favorite, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nari Shakthi', style: TextStyle(fontFamily: kSerif, fontVariations: kSerifBold, fontSize: 24, color: fg, height: 1.05)),
              const Text('MATRIMONY', style: TextStyle(fontSize: 10, letterSpacing: 5, fontWeight: FontWeight.w700, color: Palette.marigold)),
            ]),
          ]),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown, alignment: Alignment.centerRight,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _NavTab('Home', Icons.home_outlined, active: _tab == 'home', solid: _solid, onTap: () => _go('home')),
              _NavTab('About us', Icons.info_outline, active: _tab == 'about', solid: _solid, onTap: () => _go('about')),
              _NavTab('Success stories', Icons.auto_awesome_outlined, active: _tab == 'stories', solid: _solid, onTap: () => _go('stories')),
              _NavTab('Donate', Icons.volunteer_activism_outlined, active: _tab == 'donate', solid: _solid, onTap: () => _go('donate')),
              _NavTab('Search profiles', Icons.search, active: false, solid: _solid, onTap: _search),
              const SizedBox(width: 12),
              _NavTab('Sign in', Icons.login, active: false, solid: _solid, onTap: () => _auth()),
              const SizedBox(width: 10),
              SitePill('Register free', compact: true, icon: Icons.person_add_alt_1, onTap: () => _auth(true)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _page() {
    switch (_tab) {
      case 'about':
        return AboutPage(onRegister: () => _auth(true), onSearch: _search);
      case 'stories':
        return StoriesPage(onRegister: () => _auth(true));
      case 'donate':
        return const DonatePage();
      default:
        return _home();
    }
  }

  Widget _trust(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, color: Palette.marigold, size: 20), const SizedBox(width: 8), Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5))]);

  Widget _perk(IconData i, String t) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Palette.blush, borderRadius: BorderRadius.circular(12)), child: Icon(i, color: Palette.plum, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Padding(padding: const EdgeInsets.only(top: 6), child: Text(t, style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600)))),
      ]));

  Widget _heroCard() => Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 40, offset: const Offset(0, 18))]),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Find your match', style: TextStyle(fontFamily: kSerif, fontVariations: kSerifBold, fontSize: 28, fontWeight: FontWeight.w800, color: Palette.plumDeep)),
          const SizedBox(height: 6),
          const Text('Free to join. Private by design.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 22),
          _perk(Icons.verified_user_outlined, 'Every profile is reviewed by an admin'),
          _perk(Icons.lock_outline, 'You decide who can see your photos'),
          _perk(Icons.forum_outlined, 'Chat opens only after both agree'),
          const SizedBox(height: 8),
          SitePill('Search profiles', icon: Icons.search, onTap: _search),
          const SizedBox(height: 12),
          SitePill('Create free account', icon: Icons.person_add_alt_1, filled: false, onDark: false, onTap: () => _auth(true)),
        ]),
      );

  Widget _hero() => SizedBox(
      height: 720,
      child: Stack(fit: StackFit.expand, children: [
        const SiteImage('assets/web/hero.jpg'),
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight,
            colors: [Palette.plumDeep.withOpacity(.94), Palette.plumDeep.withOpacity(.6), Colors.transparent], stops: const [0, .58, 1]))),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 90, 40, 30),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: FadeIn(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('EXCLUSIVELY FOR SECOND MARRIAGES', style: TextStyle(letterSpacing: 4, fontSize: 13, fontWeight: FontWeight.w800, color: Palette.marigold)),
                    const SizedBox(height: 18),
                    const Text('Find your partner for a beautiful second beginning', style: TextStyle(fontFamily: kSerif, fontVariations: kSerifBold, fontSize: 54, fontWeight: FontWeight.w800, color: Colors.white, height: 1.12)),
                    const SizedBox(height: 18),
                    const Text('A trusted, private introduction platform for divorced, widowed and legally separated men and women.', style: TextStyle(fontSize: 19, height: 1.55, color: Colors.white70)),
                    const SizedBox(height: 30),
                    Wrap(spacing: 16, runSpacing: 12, children: [
                      SitePill('Register free', icon: Icons.person_add_alt_1, onTap: () => _auth(true)),
                      SitePill('About us', filled: false, onTap: () => _go('about')),
                    ]),
                    const SizedBox(height: 34),
                    Wrap(spacing: 26, runSpacing: 10, children: [
                      _trust(Icons.verified_user_outlined, 'Admin-verified profiles'),
                      _trust(Icons.lock_outline, 'Photos stay private'),
                      _trust(Icons.forum_outlined, 'Chat with consent'),
                    ]),
                  ])),
                ),
                const SizedBox(width: 40),
                SizedBox(width: 380, child: FadeIn(delayMs: 300, child: _heroCard())),
              ]),
            ),
          ),
        ),
      ]));

  Widget _home() => Column(children: [
        _hero(),
        SiteSection(
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              flex: 6,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SiteHeading('Who we are', 'A new beginning, with dignity', center: false),
                const SizedBox(height: 22),
                const Text('Nari Shakthi Matrimony is a social-service introduction platform, a parichaya vedika, for people who are rebuilding their lives after divorce, widowhood or legal separation. We bring them together with respect, privacy and care, so that a difficult chapter can be followed by a happy one.',
                    style: TextStyle(fontSize: 17.5, height: 1.7, color: Colors.black87)),
                const SizedBox(height: 26),
                SitePill('Read about us', filled: false, onDark: false, icon: Icons.arrow_forward, onTap: () => _go('about')),
              ]),
            ),
            const SizedBox(width: 56),
            Expanded(
              flex: 5,
              child: SizedBox(height: 320, child: ClipRRect(borderRadius: BorderRadius.circular(26), child: const SiteImage('assets/web/story1.jpg'))),
            ),
          ]),
        ),
        SiteSection(
          color: Palette.mist,
          child: Column(children: [
            const SiteHeading('How it works', 'Four simple steps'),
            const SizedBox(height: 44),
            LayoutBuilder(builder: (c, box) {
              const steps = [
                (Icons.person_add_alt_1, 'Create your profile', 'Register free and tell us about yourself and who you are looking for.'),
                (Icons.verified_user, 'Admin verification', 'Every profile is reviewed by our admin team before it is shown.'),
                (Icons.favorite_border, 'Find and send interest', 'Browse profiles and send an interest to the ones you like.'),
                (Icons.forum_outlined, 'Connect with consent', 'Photos and chat open only after the other person accepts.'),
              ];
              final w = (box.maxWidth - 24 * 3) / 4;
              return Wrap(spacing: 24, runSpacing: 24, children: [for (final s in steps) SizedBox(width: w, child: FeatureCard(s.$1, s.$2, s.$3))]);
            }),
          ]),
        ),
        SiteSection(
          child: Column(children: [
            const SiteHeading('Happy beginnings', 'Success stories', sub: 'People who found companionship and peace again.'),
            const SizedBox(height: 44),
            LayoutBuilder(builder: (c, box) {
              final w = (box.maxWidth - 28 * 2) / 3;
              return Wrap(spacing: 28, runSpacing: 28, children: [for (final s in successStories.take(3)) SizedBox(width: w, child: StoryCard(s))]);
            }),
            const SizedBox(height: 40),
            SitePill('See all success stories', filled: false, onDark: false, icon: Icons.arrow_forward, onTap: () => _go('stories')),
          ]),
        ),
        const QuoteBand(),
        SiteSection(
          color: Palette.mist,
          child: Column(children: [
            const SiteHeading('Why Nari Shakthi', 'Built to be safe and respectful'),
            const SizedBox(height: 44),
            LayoutBuilder(builder: (c, box) {
              const items = [
                (Icons.verified_user_outlined, 'Verified profiles', 'An admin reviews every profile before it appears.'),
                (Icons.lock_outline, 'Private photos', 'Photos are visible only to signed-in members you allow.'),
                (Icons.forum_outlined, 'Consent-based chat', 'You can talk only after both people accept.'),
                (Icons.shield_outlined, 'Report and block', 'Any member can block or report someone who breaks the rules.'),
              ];
              final w = (box.maxWidth - 24 * 3) / 4;
              return Wrap(spacing: 24, runSpacing: 24, children: [for (final s in items) SizedBox(width: w, child: FeatureCard(s.$1, s.$2, s.$3))]);
            }),
          ]),
        ),
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 32),
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.plumDeep, Palette.plum, Palette.crimson])),
          child: Column(children: [
            const Text('Your next chapter starts here', textAlign: TextAlign.center, style: TextStyle(fontFamily: kSerif, fontVariations: kSerifBold, fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 12),
            const Text('Join free and meet someone who understands your journey.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.white70)),
            const SizedBox(height: 28),
            Wrap(spacing: 16, runSpacing: 12, alignment: WrapAlignment.center, children: [
              SitePill('Register free', icon: Icons.person_add_alt_1, onTap: () => _auth(true)),
              SitePill('Donate', icon: Icons.volunteer_activism, filled: false, onTap: () => _go('donate')),
            ]),
          ]),
        ),
      ]);

  Widget _footer() => Container(
        width: double.infinity, color: Palette.plumDeep, padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kSiteWidth),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Nari Shakthi', style: TextStyle(fontFamily: kSerif, fontVariations: kSerifBold, fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('MATRIMONY', style: TextStyle(fontSize: 11, letterSpacing: 5, fontWeight: FontWeight.w700, color: Palette.marigold)),
                    SizedBox(height: 14),
                    Text('A social-service introduction platform for second marriages.', style: TextStyle(color: Colors.white70, height: 1.5)),
                  ]),
                ),
                Wrap(spacing: 28, children: [
                  for (final l in const [('Home', 'home'), ('About us', 'about'), ('Success stories', 'stories'), ('Donate', 'donate')])
                    InkWell(onTap: () => _go(l.$2), child: Text(l.$1, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
                ]),
              ]),
              const SizedBox(height: 28),
              Container(height: 1, color: Colors.white24),
              const SizedBox(height: 18),
              const Text('\u00a9 2026 Nari Shakthi Matrimony. Developed by Codesoftwares.', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Stack(children: [
          SingleChildScrollView(controller: _scroll, child: Column(children: [_page(), _footer()])),
          Positioned(top: 0, left: 0, right: 0, child: _nav()),
        ]),
      );
}

/// One tab in the top menu: pill shape, hover highlight, filled when it is the open page.
class _NavTab extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active, solid;
  final VoidCallback onTap;
  const _NavTab(this.label, this.icon, {required this.active, required this.solid, required this.onTap});
  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final solid = widget.solid, active = widget.active;
    final fg = active ? Colors.white : (solid ? Palette.plumDeep : Colors.white);
    final bg = active
        ? (solid ? Palette.plum : Colors.white.withOpacity(.22))
        : (_h ? (solid ? Palette.plum.withOpacity(.09) : Colors.white.withOpacity(.14)) : Colors.transparent);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true), onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180), margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30), border: active && !solid ? Border.all(color: Colors.white54) : null),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, size: 17, color: fg), const SizedBox(width: 7),
            Text(widget.label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14.5)),
          ]),
        ),
      ),
    );
  }
}

class _SearchDialog extends StatelessWidget {
  final VoidCallback onClose, onNeedLogin;
  const _SearchDialog({required this.onClose, required this.onNeedLogin});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false, backgroundColor: Colors.transparent,
            title: const Text('Search profiles', style: TextStyle(fontWeight: FontWeight.w800, color: Palette.plum)),
            actions: [IconButton(icon: const Icon(Icons.close), onPressed: onClose)]),
        body: SearchScreen(onNeedLogin: onNeedLogin),
      );
}
