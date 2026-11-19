// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

/// Asks the admin for a reason (required when suspending). Returns null if cancelled, '' if left empty.
Future<String?> askReason(BuildContext c, {required String title, required bool required}) {
  final ctl = TextEditingController();
  String? err;
  return showDialog<String>(
    context: c,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('This reason is shown to the member.'),
          const SizedBox(height: 12),
          TextField(controller: ctl, maxLines: 3, maxLength: 300,
              decoration: InputDecoration(labelText: required ? 'Reason (required)' : 'Reason (optional)', errorText: err)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final t = ctl.text.trim();
              if (required && t.length < 3) { set(() => err = 'Please write a short reason.'); return; }
              Navigator.pop(ctx, t);
            },
            child: const Text('Confirm', style: TextStyle(color: Palette.crimson, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    ),
  );
}

/// Admin view of one member: every profile detail, all photos, and Approve / Reject / Suspend.
class AdminMemberScreen extends StatefulWidget {
  final String id;
  const AdminMemberScreen({super.key, required this.id});
  @override
  State<AdminMemberScreen> createState() => _AdminMemberScreenState();
}

class _AdminMemberScreenState extends State<AdminMemberScreen> {
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
      _d = await Api.call('GET', '/admin/users/${widget.id}');
      _err = null;
    } on ApiError catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() {});
  }

  Future<void> _set(String s) async {
    var reason = '';
    if (s != 'approved') {
      final r = await askReason(context, title: s == 'suspended' ? 'Suspend this member?' : 'Reject this member?', required: s == 'suspended');
      if (r == null || !mounted) return;
      reason = r;
    }
    setState(() => _busy = true);
    await guarded(context, () async {
      final m = (await Api.call('POST', '/admin/users/${widget.id}/status', body: {'status': s, 'reason': reason}))['message'] as String;
      await _load();
      return m;
    });
    if (mounted) setState(() => _busy = false);
  }

  void _viewPhoto(String id) => showDialog(
      context: context,
      builder: (c) => Dialog(
          child: InteractiveViewer(child: Image.network('$apiBase/photos/$id', headers: Api.authHeaders, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(30), child: Text('Could not load the photo.'))))));

  Widget _row(String label, Object? v) {
    final t = v?.toString().trim() ?? '';
    if (t.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.black54))),
        Expanded(child: SelectableText(t, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Member details', style: TextStyle(fontWeight: FontWeight.w800, color: Palette.plum))),
      body: d == null
          ? (_err == null ? const Center(child: CircularProgressIndicator()) : EmptyState(Icons.info_outline, _err!))
          : _body(d),
    );
  }

  Widget _body(Map<String, dynamic> d) {
    final p = d['profile'] as Map<String, dynamic>?, status = d['status'] as String;
    final photos = (d['photos'] as List).cast<Map<String, dynamic>>();
    String yn(Object? v) => v == true ? 'Yes' : 'No';
    return ListView(padding: const EdgeInsets.all(16), children: [
      FormCard(p?['name'] as String? ?? 'Profile not completed', Icons.person_outline, [
        Align(alignment: Alignment.centerLeft, child: Chip(label: Text(status.toUpperCase()), backgroundColor: Palette.mist, side: BorderSide(color: Palette.plum.withOpacity(.4)))),
        const SizedBox(height: 8),
        _row('Email', d['email']),
        _row('Joined', '${d['joined']}'.split('.').first),
        _row('Reason', d['status_reason']),
      ]),
      if (p != null) ...[
        FormCard('About', Icons.badge_outlined, [
          _row('Age', p['age']), _row('Gender', genderOptions[p['gender']] ?? p['gender']), _row('City / town', p['location']), _row('Address', p['address']),
          _row('Education', p['education']), _row('Occupation', p['occupation']), _row('Marital status', maritalOptions[p['marital_status']] ?? p['marital_status']), _row('Marriage details', p['marriage_details']),
        ]),
        FormCard('Family', Icons.family_restroom, [
          _row('Has children', yn(p['has_children'])), _row('Children', p['children_info']), _row('Family details', p['family_details']),
        ]),
        FormCard('Looking for', Icons.favorite_border, [
          _row('Age range', (p['pref_age_min'] == null && p['pref_age_max'] == null) ? null : '${p['pref_age_min'] ?? '?'} to ${p['pref_age_max'] ?? '?'}'),
          _row('Location', p['pref_location']), _row('Education', p['pref_education']), _row('Occupation', p['pref_occupation']),
          _row('Marital status', maritalOptions[p['pref_marital_status']] ?? p['pref_marital_status']),
        ]),
        FormCard('Contact', Icons.phone_outlined, [
          _row('Mobile', p['phone']), _row('WhatsApp', p['whatsapp']), _row('Contact email', p['contact_email']),
          _row('Public contact', [if (p['show_phone'] == true) 'Mobile', if (p['show_whatsapp'] == true) 'WhatsApp', if (p['show_email'] == true) 'Email'].join(', ')),
          _row('Photos private', yn(p['photos_private'])),
        ]),
      ] else
        const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('This member has not completed the profile yet.')),
      FormCard('Photos', Icons.photo_library_outlined, [
        if (photos.isEmpty) const Text('No photos added.')
        else Wrap(spacing: 12, runSpacing: 12, children: [for (final ph in photos) GestureDetector(onTap: () => _viewPhoto(ph['id'] as String), child: Avatar(ph['id'] as String, size: 120))]),
      ]),
      if (status != 'approved') AppButton(status == 'suspended' ? 'Reactivate member' : 'Approve member', icon: Icons.check, loading: _busy, onPressed: () => _set('approved')),
      if (status == 'pending') ...[const SizedBox(height: 10), AppButton('Reject', icon: Icons.close, kind: BtnKind.secondary, onPressed: _busy ? null : () => _set('rejected'))],
      if (status == 'approved' || status == 'pending') ...[const SizedBox(height: 10), AppButton('Suspend (rule violation)', icon: Icons.block, kind: BtnKind.danger, onPressed: _busy ? null : () => _set('suspended'))],
      const SizedBox(height: 24),
    ]);
  }
}
