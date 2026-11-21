// Developed by Codesoftwares
import 'dart:async';
import 'package:flutter/material.dart';
import 'stories.dart';
import 'theme.dart';

const double kSiteWidth = 1160;

/// Fades and slides its child in once.
class FadeIn extends StatelessWidget {
  final Widget child;
  final int delayMs;
  const FadeIn({super.key, required this.child, this.delayMs = 0});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 800 + delayMs), curve: Curves.easeOutCubic,
        builder: (c, v, ch) => Opacity(opacity: v.clamp(0.0, 1.0).toDouble(), child: Transform.translate(offset: Offset(0, 26 * (1 - v)), child: ch)),
        child: child,
      );
}

/// Lifts its child a little when the mouse is over it (website).
class HoverLift extends StatefulWidget {
  final Widget child;
  const HoverLift({super.key, required this.child});
  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _h = true), onExit: (_) => setState(() => _h = false),
        child: AnimatedContainer(duration: const Duration(milliseconds: 220), curve: Curves.easeOut, transform: Matrix4.translationValues(0, _h ? -8 : 0, 0), child: widget.child),
      );
}

/// A picture from assets with a warm gradient if the file is missing.
class SiteImage extends StatelessWidget {
  final String path;
  const SiteImage(this.path, {super.key});
  @override
  Widget build(BuildContext context) => Image.asset(path, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
      errorBuilder: (_, __, ___) => const DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.plumDeep, Palette.plum, Palette.marigold]))));
}

/// Rounded button used on the website. `onDark` = white outline for dark backgrounds, plum outline otherwise.
class SitePill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled, compact, onDark;
  final IconData? icon;
  const SitePill(this.label, {super.key, required this.onTap, this.filled = true, this.compact = false, this.onDark = true, this.icon});
  @override
  Widget build(BuildContext context) {
    final pad = EdgeInsets.symmetric(horizontal: compact ? 22 : 32, vertical: compact ? 13 : 18);
    final text = TextStyle(fontSize: compact ? 14.5 : 16.5, fontWeight: FontWeight.w800);
    final kids = Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)], Text(label)]);
    return filled
        ? ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: Palette.marigold, foregroundColor: Palette.plumDeep, elevation: 0, padding: pad, shape: const StadiumBorder(), textStyle: text), child: kids)
        : OutlinedButton(onPressed: onTap, style: OutlinedButton.styleFrom(foregroundColor: onDark ? Colors.white : Palette.plum, side: BorderSide(color: onDark ? Colors.white : Palette.plum, width: 1.6), padding: pad, shape: const StadiumBorder(), textStyle: text), child: kids);
  }
}

/// Full-width band with centred, max-width content.
class SiteSection extends StatelessWidget {
  final Color? color;
  final double vertical;
  final Widget child;
  const SiteSection({super.key, this.color, this.vertical = 80, required this.child});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity, color: color, padding: EdgeInsets.symmetric(vertical: vertical, horizontal: 32),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: kSiteWidth), child: child)));
}

class SiteHeading extends StatelessWidget {
  final String eyebrow, title;
  final String? sub;
  final bool light, center;
  const SiteHeading(this.eyebrow, this.title, {super.key, this.sub, this.light = false, this.center = true});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
        Text(eyebrow.toUpperCase(), style: const TextStyle(letterSpacing: 4, fontSize: 13, fontWeight: FontWeight.w800, color: Palette.marigold)),
        const SizedBox(height: 10),
        Text(title, textAlign: center ? TextAlign.center : TextAlign.start,
            style: TextStyle(fontFamily: kSerif, fontVariations: kSerifBold, fontSize: 38, fontWeight: FontWeight.w800, height: 1.2, color: light ? Colors.white : Palette.plumDeep)),
        if (sub != null) ...[
          const SizedBox(height: 12),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720),
              child: Text(sub!, textAlign: center ? TextAlign.center : TextAlign.start, style: TextStyle(fontSize: 17, height: 1.55, color: light ? Colors.white70 : Colors.black54))),
        ],
      ]);
}

/// Top banner of the inner pages (About, Success stories, Donate).
class PageBanner extends StatelessWidget {
  final String title, subtitle, image;
  const PageBanner(this.title, this.subtitle, this.image, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 360,
      child: Stack(fit: StackFit.expand, children: [
        SiteImage(image),
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.plumDeep.withOpacity(.88), Palette.plumDeep.withOpacity(.62)]))),
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: kSerif, fontVariations: kSerifBold, fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15)),
            const SizedBox(height: 14),
            Container(height: 3, width: 70, decoration: BoxDecoration(color: Palette.marigold, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, height: 1.5, color: Colors.white70)),
          ]))),
        ),
      ]));
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const FeatureCard(this.icon, this.title, this.text, {super.key});
  @override
  Widget build(BuildContext context) => HoverLift(child: Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: Palette.plum.withOpacity(.14)),
          boxShadow: [BoxShadow(color: Palette.plum.withOpacity(.07), blurRadius: 24, offset: const Offset(0, 10))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 56, height: 56, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Palette.plum, Palette.crimson]), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: Colors.white, size: 28)),
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Palette.plumDeep)),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(fontSize: 15.5, height: 1.55, color: Colors.black54)),
      ])));
}

class StoryCard extends StatelessWidget {
  final Story story;
  const StoryCard(this.story, {super.key});
  @override
  Widget build(BuildContext context) => HoverLift(child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: Palette.plum.withOpacity(.14)),
          boxShadow: [BoxShadow(color: Palette.plum.withOpacity(.08), blurRadius: 24, offset: const Offset(0, 10))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 210, child: SiteImage(story.image)),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(story.title, style: const TextStyle(fontFamily: kSerif, fontVariations: kSerifBold, fontSize: 22, fontWeight: FontWeight.w800, color: Palette.plumDeep)),
            const SizedBox(height: 10),
            Text(story.text, style: const TextStyle(fontSize: 15.5, height: 1.6, color: Colors.black54)),
            const SizedBox(height: 12),
            const Text('Illustrative story', style: TextStyle(fontSize: 12.5, color: Palette.marigold, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700)),
          ]),
        ),
      ])));
}

/// Large rotating quote over a picture.
class QuoteBand extends StatefulWidget {
  const QuoteBand({super.key});
  @override
  State<QuoteBand> createState() => _QuoteBandState();
}

class _QuoteBandState extends State<QuoteBand> {
  int _q = 0;
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 7), (_) => setState(() => _q = (_q + 1) % successQuotes.length));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 440,
      child: Stack(fit: StackFit.expand, children: [
        const SiteImage('assets/web/quote.jpg'),
        DecoratedBox(decoration: BoxDecoration(color: Palette.plumDeep.withOpacity(.58))),
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.format_quote, size: 56, color: Palette.marigold),
          AnimatedSwitcher(duration: const Duration(milliseconds: 700),
              child: Text(successQuotes[_q], key: ValueKey(_q), textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: kSerif, fontVariations: kSerifBold, fontSize: 38, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, color: Colors.white, height: 1.35))),
          const SizedBox(height: 26),
          Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < successQuotes.length; i++) Container(width: i == _q ? 26 : 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(color: i == _q ? Palette.marigold : Colors.white38, borderRadius: BorderRadius.circular(4)))]),
        ])))),
      ]));
}
