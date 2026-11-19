// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';

void snack(BuildContext c, String m, {bool error = false}) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, backgroundColor: error ? Palette.crimson : Palette.plum));

/// Runs an action, shows the returned message, or the error in plain words.
Future<void> guarded(BuildContext c, Future<String?> Function() fn) async {
  try {
    final m = await fn();
    if (m != null && c.mounted) snack(c, m);
  } on ApiError catch (e) {
    if (c.mounted) snack(c, e.message, error: true);
  }
}

class Drop extends StatelessWidget {
  final String label;
  final String? value;
  final Map<String, String> options; // value -> label
  final ValueChanged<String?> onChanged;
  final String? errorText;
  const Drop(this.label, this.value, this.options, this.onChanged, {super.key, this.errorText});
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        value: value, isExpanded: true, decoration: InputDecoration(labelText: label, errorText: errorText),
        items: options.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: onChanged);
}

const maritalOptions = {'divorced': 'Divorced', 'widowed': 'Widowed', 'legally_separated': 'Legally separated'};
const genderOptions = {'male': 'Male', 'female': 'Female'};

class Avatar extends StatelessWidget {
  final String? photoId;
  final double size;
  const Avatar(this.photoId, {super.key, this.size = 64});
  @override
  Widget build(BuildContext context) {
    final icon = Container(width: size, height: size, decoration: BoxDecoration(color: Palette.mist, borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.person, size: size * .6, color: Palette.plum));
    if (photoId == null) return icon;
    return ClipRRect(borderRadius: BorderRadius.circular(16),
        child: Image.network(Api.photoUrl(photoId!), headers: Api.authHeaders, width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => icon));
  }
}

/// One card for every member list (search, shortlist, inbox, admin).
class MemberTile extends StatelessWidget {
  final String? photoId;
  final String title, subtitle;
  final String? badge;
  final List<Widget> actions;
  final String? memberId; // when set, shows a Report / Block menu
  final VoidCallback? onTap; // when set, the whole card is tappable (admin: open member details)
  const MemberTile({super.key, this.photoId, required this.title, required this.subtitle, this.badge, this.actions = const [], this.memberId, this.onTap});
  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(photoId),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
                if (badge != null) Padding(padding: const EdgeInsets.only(top: 6),
                    child: Chip(label: Text(badge!), visualDensity: VisualDensity.compact, backgroundColor: Palette.mist, side: BorderSide.none)),
              ])),
              if (memberId != null) IconButton(tooltip: 'Report or block', icon: const Icon(Icons.more_vert), onPressed: () => showSafety(context, memberId!, title.split(',').first)),
              if (onTap != null) const Icon(Icons.chevron_right, color: Palette.plum),
            ]),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: actions[i])]]),
            ],
          ]),
        )),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(40),
      child: Column(children: [Icon(icon, size: 52, color: Palette.plum.withOpacity(.5)), const SizedBox(height: 12), Text(text, textAlign: TextAlign.center)]));
}

/// Loads a list and shows loading / error / empty states.
class AsyncList extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() load;
  final Widget Function(BuildContext, Map<String, dynamic>, VoidCallback reload) item;
  final String emptyText;
  final Widget? header;
  const AsyncList({super.key, required this.load, required this.item, required this.emptyText, this.header});
  @override
  State<AsyncList> createState() => AsyncListState();
}

class AsyncListState extends State<AsyncList> {
  late Future<List<Map<String, dynamic>>> _f = widget.load();
  void reload() => setState(() => _f = widget.load());
  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async => reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _f,
          builder: (c, snap) {
            final head = widget.header == null ? <Widget>[] : [widget.header!];
            if (snap.connectionState != ConnectionState.done) return ListView(padding: const EdgeInsets.all(16), children: [...head, const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))]);
            if (snap.hasError) return ListView(padding: const EdgeInsets.all(16), children: [...head, EmptyState(Icons.info_outline, snap.error is ApiError ? (snap.error as ApiError).message : 'Something went wrong.')]);
            final items = snap.data!;
            return ListView(padding: const EdgeInsets.all(16), children: [
              ...head,
              if (items.isEmpty) EmptyState(Icons.inbox_outlined, widget.emptyText),
              for (final m in items) widget.item(c, m, reload),
            ]);
          },
        ),
      );
}

const _reportReasons = {
  'fake_profile': 'Fake profile', 'harassment': 'Harassment or abuse', 'inappropriate_content': 'Inappropriate content',
  'asking_for_money': 'Asking for money', 'other': 'Something else'};

/// Report / block sheet, used from member cards and the chat screen.
Future<void> showSafety(BuildContext c, String memberId, String name) async {
  final choice = await showModalBottomSheet<String>(
      context: c, showDragHandle: true,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.flag_outlined), title: Text('Report $name'), onTap: () => Navigator.pop(ctx, 'report')),
            ListTile(leading: const Icon(Icons.block, color: Palette.crimson), title: Text('Block $name'), onTap: () => Navigator.pop(ctx, 'block')),
          ])));
  if (choice == null || !c.mounted) return;
  if (choice == 'block') {
    final ok = await showDialog<bool>(context: c, builder: (ctx) => AlertDialog(
        title: Text('Block $name?'), content: const Text('You will no longer see each other in search, interests or chat. You can unblock later from your Profile.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Block', style: TextStyle(color: Palette.crimson)))]));
    if (ok == true && c.mounted) await guarded(c, () async => (await Api.call('POST', '/blocks/$memberId'))['message'] as String);
    return;
  }
  String? reason;
  final details = TextEditingController();
  final send = await showDialog<bool>(context: c, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: Text('Report $name'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Drop('Reason', reason, _reportReasons, (v) => set(() => reason = v)),
        const SizedBox(height: 12),
        TextField(controller: details, maxLines: 3, maxLength: 500, decoration: const InputDecoration(labelText: 'Details (optional)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(onPressed: reason == null ? null : () => Navigator.pop(ctx, true), child: const Text('Send report'))])));
  if (send == true && c.mounted) {
    await guarded(c, () async => (await Api.call('POST', '/reports', body: {'target': memberId, 'reason': reason, 'details': details.text}))['message'] as String);
  }
}

/// A clearly bordered section for forms (icon + title + divider), used on every form screen.
class FormCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const FormCard(this.title, this.icon, this.children, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(.94), borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Palette.plum.withOpacity(.35), width: 1.4),
            boxShadow: [BoxShadow(color: Palette.plum.withOpacity(.08), blurRadius: 14, offset: const Offset(0, 6))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Palette.blush, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 22, color: Palette.plum)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Palette.plumDeep))),
          ]),
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Container(height: 2, decoration: BoxDecoration(color: Palette.marigold.withOpacity(.55), borderRadius: BorderRadius.circular(2)))),
          ...children,
        ]),
      );
}
