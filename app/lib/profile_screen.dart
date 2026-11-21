// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api.dart';
import 'blocked_screen.dart';
import 'change_password_screen.dart';
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

  Widget _chip(String t) => t.isEmpty
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: Colors.white.withOpacity(.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white38)),
          child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)));

  Widget _hero(Map<String, dynamic> p) => Container(
        margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.plum, Palette.crimson]),
            borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: Palette.plum.withOpacity(.3), blurRadius: 22, offset: const Offset(0, 10))]),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Avatar(_photos.isEmpty ? null : _photos.first, size: 84)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['name']}', style: const TextStyle(fontFamily: kSerif, fontVariations: kSerifBold, fontSize: 24, color: Colors.white, height: 1.15)),
              const SizedBox(height: 4),
              Text('${p['age']} years  •  ${p['location'] ?? ''}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [_chip(maritalOptions[p['marital_status']] ?? ''), if (p['has_children'] == true) _chip('Has children')]),
            ]),
          ),
        ]),
      );

  Widget _photoGrid(Map<String, dynamic> p) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (c, box) {
          final w = (box.maxWidth - 24) / 3;
          Widget tile(Widget child) => SizedBox(width: w, height: w, child: child);
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final id in _photos)
              tile(ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(fit: StackFit.expand, children: [
                  GestureDetector(
                    onTap: () => viewPhotoDialog(context, id),
                    child: Image.network(Api.photoUrl(id), headers: Api.authHeaders, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Palette.mist, child: const Icon(Icons.broken_image_outlined, color: Palette.plum))),
                  ),
                  Positioned(right: 6, top: 6, child: _mini(Icons.close, Palette.crimson, () => _deletePhoto(id))),
                  Positioned(right: 6, bottom: 6, child: _mini(Icons.edit, Palette.plum, () => _replacePhoto(id))),
                ]),
              )),
            if (_photos.length < _maxPhotos)
              tile(InkWell(
                onTap: _addPhoto, borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(color: Palette.blush.withOpacity(.6), borderRadius: BorderRadius.circular(16), border: Border.all(color: Palette.plum.withOpacity(.45), width: 1.6)),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_a_photo_outlined, color: Palette.plum, size: 28), SizedBox(height: 6),
                    Text('Add photo', style: TextStyle(color: Palette.plum, fontWeight: FontWeight.w600, fontSize: 12.5)),
                  ]),
                ),
              )),
          ]);
        }),
        const SizedBox(height: 14),
        Text('${_photos.length} of $_maxPhotos photos  •  ${p['photos_private'] == false ? 'visible to every signed-in member' : 'private (shown after you accept an interest)'}',
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
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
        AppButton('Change password', icon: Icons.lock_reset, kind: BtnKind.secondary, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
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
        _hero(p),
        FormCard('My photos', Icons.photo_library_outlined, [_photoGrid(p)]),
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
