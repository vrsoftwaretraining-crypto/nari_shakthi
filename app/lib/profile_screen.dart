// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api.dart';
import 'blocked_screen.dart';
import 'profile_edit_screen.dart';
import 'profile_widgets.dart';
import 'theme.dart';
import 'widgets.dart';

/// My profile, shown as a normal page (not text boxes). Edit, delete, and manage up to 6 photos from here.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _maxPhotos = 6;
  Map<String, dynamic>? _p;
  List<String> _photos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _p = (await Api.call('GET', '/profile'))['profile'] as Map<String, dynamic>?;
      _photos = (await Api.list('/photos', 'photos')).map((e) => e['id'] as String).toList();
    } on ApiError catch (e) {
      if (mounted) snack(context, e.message, error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ProfileEditScreen(initial: _p)));
    if (ok == true) _load();
  }

  Future<void> _addPhoto() => guarded(context, () async {
        final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
        if (f == null) return null;
        final m = await Api.upload('/photos', f);
        await _load();
        return m;
      });

  Future<void> _replacePhoto(String id) => guarded(context, () async {
        final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
        if (f == null) return null;
        final m = await Api.upload('/photos/$id', f, method: 'PUT');
        await _load();
        return m;
      });

  Future<bool> _confirm(String title, String text, String yes) async =>
      await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(title), content: Text(text), actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(yes, style: const TextStyle(color: Palette.crimson, fontWeight: FontWeight.w800))),
      ])) ==
      true;

  Future<void> _deletePhoto(String id) async {
    if (!await _confirm('Delete this photo?', 'The photo will be removed from your profile.', 'Delete') || !mounted) return;
    await guarded(context, () async {
      final m = (await Api.call('DELETE', '/photos/$id'))['message'] as String;
      await _load();
      return m;
    });
  }

  Future<void> _deleteProfile() async {
    if (!await _confirm('Delete profile details?',
            'Your profile details and all photos will be removed and you will no longer appear in search. Your login stays, so you can create the profile again.', 'Delete') ||
        !mounted) {
      return;
    }
    await guarded(context, () async {
      final m = (await Api.call('DELETE', '/profile'))['message'] as String;
      await _load();
      return m;
    });
  }

  Future<void> _deleteAccount() async {
    final pw = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: const Text('Delete your account?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('This permanently removes your profile, photos, messages and payment screenshots. It cannot be undone.'),
            const SizedBox(height: 12),
            TextField(controller: pw, obscureText: true, decoration: const InputDecoration(labelText: 'Enter your password')),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Palette.crimson)))]));
    if (ok != true || !mounted) return;
    await guarded(context, () async {
      await Api.call('DELETE', '/account', body: {'password': pw.text});
      await Api.signOut();
      return null;
    });
  }

  Widget _mini(IconData i, Color c, VoidCallback f) => InkWell(onTap: f, child: CircleAvatar(radius: 13, backgroundColor: c, child: Icon(i, size: 15, color: Colors.white)));

  Widget _photosArea(Map<String, dynamic> p) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_photos.isEmpty) const Text('No photos yet. Add up to 6 photos.', style: TextStyle(color: Colors.black54))
        else PhotoStrip(_photos, size: 130, overlay: (id) => Positioned.fill(child: Stack(children: [
          Positioned(right: 4, top: 4, child: _mini(Icons.close, Palette.crimson, () => _deletePhoto(id))),
          Positioned(right: 4, bottom: 4, child: _mini(Icons.edit, Palette.plum, () => _replacePhoto(id))),
        ]))),
        const SizedBox(height: 12),
        Text('Photos ${_photos.length}/$_maxPhotos  •  ${p['photos_private'] == false ? 'visible to every signed-in member' : 'private (shown after you accept an interest)'}',
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
        if (_photos.length < _maxPhotos) ...[const SizedBox(height: 12), AppButton('Add photo', icon: Icons.add_a_photo_outlined, kind: BtnKind.secondary, onPressed: _addPhoto)],
      ]);

  Widget _contactCard(Map<String, dynamic> p) {
    bool has(String k) => (p[k] ?? '').toString().isNotEmpty;
    return FormCard('My contact details', Icons.contact_phone_outlined, [
      InfoRow('Mobile', p['phone'], trailing: VisibilityBadge(p['show_phone'] == true)),
      if (has('whatsapp')) InfoRow('WhatsApp', p['whatsapp'], trailing: VisibilityBadge(p['show_whatsapp'] == true)),
      if (has('contact_email')) InfoRow('Email', p['contact_email'], trailing: VisibilityBadge(p['show_email'] == true)),
      InfoRow('Address', p['address']),
      const Text('Private details are shown only to members whose contact request you accept. Your address is never shown to other members.', style: TextStyle(fontSize: 13, color: Colors.black54)),
    ]);
  }

  List<Widget> _footer() => [
        const SizedBox(height: 12),
        AppButton('Blocked members', icon: Icons.block, kind: BtnKind.secondary, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedScreen()))),
        const SizedBox(height: 12),
        AppButton('Delete my account', icon: Icons.delete_outline, kind: BtnKind.danger, onPressed: _deleteAccount),
        const SizedBox(height: 24),
      ];

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final p = _p;
    if (p == null) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        FormCard('Create your profile', Icons.person_add_alt_1, [
          const Text('Create your profile so other members can find you. Name, address, marriage details and a mobile number are required. You choose which contact details are public or private.',
              style: TextStyle(height: 1.5)),
          const SizedBox(height: 16),
          AppButton('Create profile', icon: Icons.add, onPressed: _edit),
        ]),
        ..._footer(),
      ]);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        FormCard('${p['name']}', Icons.person_outline, [
          Text('${p['age']} years  •  ${p['location'] ?? ''}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          _photosArea(p),
        ]),
        ...profileSections(p),
        _contactCard(p),
        AppButton('Edit profile', icon: Icons.edit_outlined, onPressed: _edit),
        const SizedBox(height: 12),
        AppButton('Delete profile details and photos', icon: Icons.delete_sweep_outlined, kind: BtnKind.secondary, onPressed: _deleteProfile),
        ..._footer(),
      ]),
    );
  }
}
