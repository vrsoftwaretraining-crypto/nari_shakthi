// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'api.dart';
import 'chat_screen.dart';
import 'member_profile_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Interests and contact requests. Tap a person to open their profile.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});
  @override
  Widget build(BuildContext context) => const DefaultTabController(
        length: 2,
        child: Column(children: [
          Material(
            color: Colors.white,
            child: TabBar(labelColor: Palette.plum, unselectedLabelColor: Colors.black54, indicatorColor: Palette.marigold, indicatorWeight: 3,
                tabs: [Tab(text: 'Interests'), Tab(text: 'Contact requests')]),
          ),
          Expanded(child: TabBarView(children: [_Interests(), _ContactRequests()])),
        ]),
      );
}

class _Interests extends StatelessWidget {
  const _Interests();
  @override
  Widget build(BuildContext context) => AsyncList(
        load: () => Api.list('/interests'), emptyText: 'No interests yet. Send one from Search.',
        item: (c, m, reload) {
          final received = m['received'] == true, status = m['status'] as String;
          final List<Widget> actions = [];
          if (received && status == 'sent') {
            actions.addAll([
              TileButton('Accept', icon: Icons.check, kind: BtnKind.success, onPressed: () => guarded(c, () async { final r = (await Api.call('POST', '/interests/${m['id']}/respond', body: {'accept': true}))['message'] as String; reload(); return r; })),
              TileButton('Decline', icon: Icons.close, kind: BtnKind.danger, onPressed: () => guarded(c, () async { final r = (await Api.call('POST', '/interests/${m['id']}/respond', body: {'accept': false}))['message'] as String; reload(); return r; })),
            ]);
          } else if (status == 'accepted') {
            actions.addAll([
              TileButton('Chat', icon: Icons.chat_bubble_outline, onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ChatScreen(interestId: m['id'] as String, name: '${m['name']}', memberId: m['member_id'] as String?)))),
              TileButton('We got married', icon: Icons.favorite, kind: BtnKind.secondary, onPressed: () async {
                final ok = await showDialog<bool>(context: c, builder: (ctx) => AlertDialog(
                    title: const Text('Report your marriage?'),
                    content: const Text('Congratulations! Our team will confirm it. After that, both profiles are removed from search.'),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, we are married'))]));
                if (ok == true && c.mounted) await guarded(c, () async => (await Api.call('POST', '/interests/${m['id']}/married'))['message'] as String);
              }),
            ]);
          }
          return MemberTile(
            onTap: () => openMember(c, m['member_id'] as String?),
            memberId: m['member_id'] as String?, photoId: m['photo_id'] as String?, title: '${m['name']}, ${m['age']}', subtitle: '${m['location'] ?? ''}',
            badge: received ? (status == 'sent' ? 'Received • waiting for you' : 'Received • $status') : 'Sent • $status', actions: actions);
        },
      );
}

class _ContactRequests extends StatelessWidget {
  const _ContactRequests();
  @override
  Widget build(BuildContext context) => AsyncList(
        load: () => Api.list('/contact-requests'), emptyText: 'No contact requests. When someone asks for your private contact details, it appears here.',
        item: (c, m, reload) {
          final status = m['status'] as String;
          Future<void> answer(bool accept) => guarded(c, () async {
                final r = (await Api.call('POST', '/contact-requests/${m['id']}/respond', body: {'accept': accept}))['message'] as String;
                reload();
                return r;
              });
          return MemberTile(
            onTap: () => openMember(c, m['member_id'] as String?),
            memberId: m['member_id'] as String?, photoId: m['photo_id'] as String?, title: '${m['name']}, ${m['age']}', subtitle: '${m['location'] ?? ''}',
            badge: {'pending': 'Wants your contact details', 'accepted': 'Can see your private contact details', 'declined': 'Declined'}[status],
            actions: [
              if (status == 'pending') ...[
                TileButton('Accept', icon: Icons.check, kind: BtnKind.success, onPressed: () => answer(true)),
                TileButton('Decline', icon: Icons.close, kind: BtnKind.danger, onPressed: () => answer(false)),
              ],
              if (status == 'accepted') TileButton('Remove access', icon: Icons.lock_outline, kind: BtnKind.secondary, onPressed: () => answer(false)),
            ],
          );
        },
      );
}

class ShortlistScreen extends StatelessWidget {
  const ShortlistScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncList(
        load: () => Api.list('/shortlist'), emptyText: 'Star profiles in Search to keep them here.',
        item: (c, m, reload) => MemberTile(
          onTap: () => openMember(c, m['user_id'] as String?),
          memberId: m['user_id'] as String?, photoId: m['photo_id'] as String?, title: '${m['name']}, ${m['age']}', subtitle: '${m['location'] ?? ''}', badge: maritalOptions[m['marital_status']],
          actions: [
            TileButton('Send interest', icon: Icons.favorite_border, onPressed: () => guarded(c, () async => (await Api.call('POST', '/interests/${m['user_id']}'))['message'] as String)),
            TileButton('Remove', icon: Icons.star, kind: BtnKind.secondary, onPressed: () => guarded(c, () async { final r = (await Api.call('DELETE', '/shortlist/${m['user_id']}'))['message'] as String; reload(); return r; })),
          ],
        ),
      );
}
