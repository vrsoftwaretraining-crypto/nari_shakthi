// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'theme.dart';

/// Opens a form (sign in, register, forgot password, search) in a centred, fixed-size card on top of the website.
Future<void> showFormDialog(BuildContext context, Widget Function(VoidCallback close) builder, {double width = 480}) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final h = (MediaQuery.of(ctx).size.height - 48).clamp(420.0, 780.0).toDouble();
        return Dialog(
          backgroundColor: Palette.mist, insetPadding: const EdgeInsets.all(24), clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          child: SizedBox(width: width, height: h, child: builder(() => Navigator.of(ctx).pop())),
        );
      },
    );
