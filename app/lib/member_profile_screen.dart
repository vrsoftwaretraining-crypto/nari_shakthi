// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'chat_screen.dart';
import 'profile_widgets.dart';
import 'theme.dart';
import 'widgets.dart';

void openMember(BuildContext c, String? id) {
  if (id == null) return;
  Navigator.push(c, MaterialPageRoute(builder: (_) => MemberProfileScreen(userId: id)));
}

/// Another member's profile. Photos follow their privacy choice; private contact details need an accepted request.
class MemberProfileScreen extends StatefulWidget {
  final String userId;
  const MemberProfileScreen({super.key, required this.userId});
  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  static const _contactMeta = {
    'phone': ('Mobile', Icons.phone_outlined), 'whatsapp': ('WhatsApp', Icons.chat_outlined), 'contact_email': ('Email', Icons.mail_outline),
  };
  Map<String, dynamic>? _d;
  String? _err;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _d = await Api.call('GET', '/members/${widget.userId}');
      _err = null;
    } on ApiError catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() {});
  }

  Future<void> _act(Future<String> Function() f) async {
    setState(() => _busy = true);
    await guarded(context, () async {
      final m = await f();
      await _load();
      return m;
    });
    if (mounted) setState(() => _busy = false);
  }

  Widget _contactRow(String k, String v) {
    final meta = _contactMeta[k]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(meta.$2, color: Palette.plum), const SizedBox(width: 12),
        SizedBox(width: 78, child: Text(meta.$1, style: const TextStyle(color: Colors.black54))),
        Expanded(child: SelectableText(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        IconButton(tooltip: 'Copy', icon: const Icon(Icons.copy, size: 20), onPressed: () { Clipboard.setData(ClipboardData(text: v)); snack(context, '${meta.$1} copied.'); }),
      ]),
    );
  }

  Widget _hiddenRow(String k) {
    final meta = _contactMeta[k]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(meta.$2, color: Colors.black38), const SizedBox(width: 12),
        Expanded(child: Text(meta.$1, style: const TextStyle(color: Colors.black54))),
        const VisibilityBadge(false),
      ]),
    );
  }

  Widget _note(String t, {IconData icon = Icons.info_outline}) => Container(
        padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(color: Palette.blush, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Palette.plum, size: 20), const SizedBox(width: 10), Expanded(child: Text(t, style: const TextStyle(fontSize: 14, height: 1.4))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final d = _d, name = (d?['profile'] as Map?)?['name'] as String? ?? 'Profile';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.plum)),
        actions: [if (d != null) IconButton(tooltip: 'Report or block', icon: const Icon(Icons.more_vert), onPressed: () => showSafety(context, widget.userId, name))],
      ),
      body: d == null ? (_err == null ? const Center(child: CircularProgressIndicator()) : EmptyState(Icons.info_outline, _err!)) : _body(d),
    );
  }

  Widget _body(Map<String, dynamic> d) {
    final p = d['profile'] as Map<String, dynamic>, photos = (d['photos'] as List).cast<String>();
    final contact = (d['contact'] as Map).cast<String, dynamic>(), hidden = (d['contact_hidden'] as List).cast<String>();
    final cr = d['contact_request'] as String?, it = d['interest'] as Map<String, dynamic>?;
    final sub = ['${p['location'] ?? ''}', maritalOptions[p['marital_status']] ?? ''].where((e) => e.isNotEmpty).join('  •  ');
    return ListView(padding: const EdgeInsets.all(16), children: [
      FormCard('${p['name']}, ${p['age']}', Icons.person_outline, [
        Text(sub, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        if (photos.isNotEmpty) PhotoStrip(photos, size: 160)
        else if (d['photos_locked'] == true) _note('Photos are private. They open when this member accepts your interest.', icon: Icons.lock_outline)
        else const Text('No photos added.', style: TextStyle(color: Colors.black54)),
      ]),
      ...profileSections(p),
      FormCard('Contact details', Icons.contact_phone_outlined, [
        for (final k in _contactMeta.keys)
          if (contact.containsKey(k)) _contactRow(k, '${contact[k]}') else if (hidden.contains(k)) _hiddenRow(k),
        if (contact.isEmpty && hidden.isEmpty) const Text('This member has not added contact details.', style: TextStyle(color: Colors.black54)),
        if (hidden.isNotEmpty) ...[
          if (cr == null) ...[
            _note('Some details are private. Send a request, and if this member accepts you will see them here.'),
            const SizedBox(height: 12),
            AppButton('Request contact details', icon: Icons.contact_phone_outlined, loading: _busy,
                onPressed: () => _act(() async => (await Api.call('POST', '/contact-requests/${widget.userId}'))['message'] as String)),
          ] else if (cr == 'pending') _note('Request sent. Waiting for this member to accept.', icon: Icons.hourglass_top)
          else if (cr == 'declined') _note('This member did not accept your request.', icon: Icons.block),
        ],
      ]),
      FormCard('Connect', Icons.favorite_border, [
        if (it == null)
          AppButton('Send interest', icon: Icons.favorite_border, loading: _busy,
              onPressed: () => _act(() async => (await Api.call('POST', '/interests/${widget.userId}'))['message'] as String))
        else ...[
          _note(it['received'] == true ? 'This member sent you an interest (${it['status']}). Answer it from your Inbox.' : 'You sent an interest (${it['status']}).', icon: Icons.favorite),
          if (it['status'] == 'accepted') ...[
            const SizedBox(height: 12),
            AppButton('Chat', icon: Icons.chat_bubble_outline,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(interestId: it['id'] as String, name: '${p['name']}', memberId: widget.userId)))),
          ],
        ],
        const SizedBox(height: 12),
        AppButton('Shortlist', icon: Icons.star_border, kind: BtnKind.secondary,
            onPressed: () => _act(() async => (await Api.call('PUT', '/shortlist/${widget.userId}'))['message'] as String)),
      ]),
      const SizedBox(height: 24),
    ]);
  }
}
