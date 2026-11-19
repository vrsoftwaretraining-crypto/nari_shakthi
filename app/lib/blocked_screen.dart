// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Blocked members', style: TextStyle(fontWeight: FontWeight.w800, color: Palette.plum))),
        body: AsyncList(
          load: () => Api.list('/blocks'), emptyText: 'You have not blocked anyone.',
          item: (c, m, reload) => MemberTile(title: '${m['name']}', subtitle: 'Blocked', actions: [
            AppButton('Unblock', icon: Icons.lock_open, kind: BtnKind.secondary, onPressed: () => guarded(c, () async { final r = (await Api.call('DELETE', '/blocks/${m['user_id']}'))['message'] as String; reload(); return r; })),
          ]),
        ),
      );
}
