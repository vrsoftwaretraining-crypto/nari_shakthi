// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';

/// Website only: once signed in, EVERY screen (including pushed pages and dialogs) runs in a centred,
/// fixed-width column on a soft background. Signed out, or on phones / narrow windows, nothing changes.
/// The widget chain is the same in both modes, so the navigator keeps its state when the mode switches.
class AdaptiveFrame extends StatelessWidget {
  final Widget child;
  const AdaptiveFrame({super.key, required this.child});
  static const double breakpoint = 900, columnWidth = 560;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final framed = mq.size.width >= breakpoint && Api.token != null;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: framed ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.plumDeep, Palette.plum, Palette.crimson]) : null),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: framed ? columnWidth : double.infinity),
          child: DecoratedBox(
            decoration: BoxDecoration(boxShadow: framed ? [BoxShadow(color: Colors.black.withOpacity(.4), blurRadius: 40)] : null),
            child: ClipRect(
              clipBehavior: framed ? Clip.hardEdge : Clip.none,
              child: MediaQuery(data: framed ? mq.copyWith(size: Size(columnWidth, mq.size.height)) : mq, child: AppBackground(child: child)),
            ),
          ),
        ),
      ),
    );
  }
}
