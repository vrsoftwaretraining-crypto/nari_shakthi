// Developed by Codesoftwares
import 'package:flutter/material.dart';

/// Wedding palette (names kept from the first version): plum = deep rose-maroon, marigold = gold, mist = ivory, blush = soft rose.
class Palette {
  static const plum = Color(0xFF8E1B4D), plumDeep = Color(0xFF5C0F33);
  static const marigold = Color(0xFFE0A030), crimson = Color(0xFFC0392B);
  static const mist = Color(0xFFFFF6EC), blush = Color(0xFFFBE4E8), ink = Color(0xFF2B1A22);
}

OutlineInputBorder _border(Color c, double w) =>
    OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));

/// Heading font (Lora). Use with fontVariations: kSerifBold for bold headings.
const String kSerif = 'Lora';
const List<FontVariation> kSerifBold = [FontVariation('wght', 700)];

ThemeData appTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      colorScheme: ColorScheme.fromSeed(seedColor: Palette.plum, primary: Palette.plum, secondary: Palette.marigold),
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Poppins', bodyColor: Palette.ink, displayColor: Palette.ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: const TextStyle(color: Palette.plumDeep, fontWeight: FontWeight.w600),
        floatingLabelStyle: const TextStyle(color: Palette.plum, fontWeight: FontWeight.w800),
        hintStyle: const TextStyle(color: Colors.black38),
        prefixIconColor: Palette.plum, suffixIconColor: Palette.plum,
        border: _border(Palette.plum.withOpacity(.55), 1.5),
        enabledBorder: _border(Palette.plum.withOpacity(.55), 1.5),
        focusedBorder: _border(Palette.plum, 2.4),
        errorBorder: _border(Palette.crimson, 1.8),
        focusedErrorBorder: _border(Palette.crimson, 2.4),
        disabledBorder: _border(Colors.black26, 1.2),
      ),
    );

/// Wedding illustration behind every screen (assets/images). Replace the JPGs to change the look.
class AppBackground extends StatelessWidget {
  final Widget child;
  final String image;
  const AppBackground({super.key, required this.child, this.image = 'assets/images/app_bg.jpg'});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: Palette.mist, image: DecorationImage(image: AssetImage(image), fit: BoxFit.cover)),
        child: child,
      );
}

enum BtnKind { primary, secondary, danger, success }

/// One button for the whole app: 56px tall, full width, clear label, optional icon, loading state.
class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final bool loading;
  final bool compact; // smaller button for cards (admin actions)
  const AppButton(this.label, {super.key, this.icon, this.onPressed, this.kind = BtnKind.primary, this.loading = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final child = loading
        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: compact ? 18 : 22), SizedBox(width: compact ? 6 : 10)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: compact ? 14 : 17, fontWeight: FontWeight.w700))),
          ]);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    final size = Size.fromHeight(compact ? 44 : 56);
    if (kind == BtnKind.secondary) {
      return OutlinedButton(
        onPressed: enabled ? onPressed : null, child: child,
        style: OutlinedButton.styleFrom(minimumSize: size, padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16), shape: shape, foregroundColor: Palette.plum,
            side: const BorderSide(color: Palette.plum, width: 1.8), backgroundColor: Colors.white.withOpacity(.6)));
    }
    final colors = kind == BtnKind.danger ? [Palette.crimson, const Color(0xFF962D22)] : [Palette.plum, Palette.plumDeep];
    return Opacity(
      opacity: enabled || loading ? 1 : .5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(16),
          border: kind == BtnKind.primary ? Border.all(color: Palette.marigold, width: 1.4) : null,
          boxShadow: [BoxShadow(color: colors.first.withOpacity(.35), blurRadius: 14, offset: const Offset(0, 6))]),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null, child: child,
          style: ElevatedButton.styleFrom(minimumSize: size, padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16), shape: shape, elevation: 0,
              backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
              foregroundColor: Colors.white, disabledBackgroundColor: Colors.transparent, disabledForegroundColor: Colors.white)),
      ),
    );
  }
}


/// Compact pill button for cards and lists (member tiles, requests). Sizes itself to its label, so it never stretches.
class TileButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final BtnKind kind;
  const TileButton(this.label, {super.key, this.icon, this.onPressed, this.kind = BtnKind.primary});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    Gradient? gradient;
    Color? bg, border;
    Color fg = Colors.white;
    switch (kind) {
      case BtnKind.primary:
        gradient = const LinearGradient(colors: [Palette.plum, Palette.plumDeep]);
      case BtnKind.success:
        gradient = const LinearGradient(colors: [Color(0xFF2E8B57), Color(0xFF1F6B42)]);
      case BtnKind.danger:
        bg = Palette.crimson.withOpacity(.08); border = Palette.crimson; fg = Palette.crimson;
      case BtnKind.secondary:
        bg = Colors.white; border = Palette.plum; fg = Palette.plum;
    }
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(gradient: gradient, color: bg, borderRadius: BorderRadius.circular(24), border: border == null ? null : Border.all(color: border, width: 1.4),
              boxShadow: gradient == null ? null : [BoxShadow(color: (gradient as LinearGradient).colors.first.withOpacity(.3), blurRadius: 10, offset: const Offset(0, 4))]),
          child: InkWell(
            borderRadius: BorderRadius.circular(24), onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 7)],
                Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
