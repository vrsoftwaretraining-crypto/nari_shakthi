// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

/// A label / value line. Empty values are skipped (unless a trailing widget is given).
class InfoRow extends StatelessWidget {
  final String label;
  final Object? value;
  final Widget? trailing;
  const InfoRow(this.label, this.value, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    final t = value?.toString().trim() ?? '';
    if (t.isEmpty && trailing == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 118, child: Text(label, style: const TextStyle(color: Colors.black54))),
        Expanded(child: SelectableText(t, style: const TextStyle(fontWeight: FontWeight.w700))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Small "Public" / "Private" badge for contact fields.
class VisibilityBadge extends StatelessWidget {
  final bool public;
  const VisibilityBadge(this.public, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: public ? Colors.green.withOpacity(.12) : Palette.blush, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: public ? Colors.green : Palette.plum.withOpacity(.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(public ? Icons.public : Icons.lock_outline, size: 14, color: public ? Colors.green.shade800 : Palette.plum),
          const SizedBox(width: 4),
          Text(public ? 'Public' : 'Private', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: public ? Colors.green.shade800 : Palette.plum)),
        ]),
      );
}

void viewPhotoDialog(BuildContext c, String id) => showDialog(
    context: c,
    builder: (_) => Dialog(
        child: InteractiveViewer(
            child: Image.network(Api.photoUrl(id), headers: Api.authHeaders, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(30), child: Text('Could not load the photo.'))))));

/// Horizontal row of photos; tap to enlarge. `overlay` can add buttons on top of each photo.
class PhotoStrip extends StatelessWidget {
  final List<String> ids;
  final double size;
  final Widget Function(String id)? overlay;
  const PhotoStrip(this.ids, {super.key, this.size = 150, this.overlay});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: size,
        child: ListView.separated(
          scrollDirection: Axis.horizontal, itemCount: ids.length, separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (c, i) => GestureDetector(onTap: () => viewPhotoDialog(c, ids[i]), child: Stack(children: [Avatar(ids[i], size: size), if (overlay != null) overlay!(ids[i])])),
        ),
      );
}

/// About, Marriage details, Family and Looking-for cards, shown as normal text (not text boxes).
List<Widget> profileSections(Map<String, dynamic> p) {
  String yn(Object? v) => v == true ? 'Yes' : 'No';
  final prefAge = (p['pref_age_min'] == null && p['pref_age_max'] == null) ? null : '${p['pref_age_min'] ?? '?'} to ${p['pref_age_max'] ?? '?'}';
  final hasPref = prefAge != null || [p['pref_location'], p['pref_education'], p['pref_occupation'], p['pref_marital_status']].any((e) => e != null && '$e'.isNotEmpty);
  return [
    FormCard('About', Icons.badge_outlined, [
      InfoRow('Age', p['age']), InfoRow('Gender', genderOptions[p['gender']] ?? p['gender']), InfoRow('City / town', p['location']),
      InfoRow('Education', p['education']), InfoRow('Occupation', p['occupation']),
    ]),
    FormCard('Marriage details', Icons.favorite_border, [
      InfoRow('Status', maritalOptions[p['marital_status']] ?? p['marital_status']), InfoRow('Details', p['marriage_details']),
    ]),
    FormCard('Family', Icons.family_restroom, [
      InfoRow('Has children', yn(p['has_children'])), InfoRow('Children', p['children_info']), InfoRow('Family details', p['family_details']),
    ]),
    if (hasPref)
      FormCard('Looking for', Icons.search, [
        InfoRow('Age range', prefAge), InfoRow('Location', p['pref_location']), InfoRow('Education', p['pref_education']),
        InfoRow('Occupation', p['pref_occupation']), InfoRow('Marital status', maritalOptions[p['pref_marital_status']] ?? p['pref_marital_status']),
      ]),
  ];
}
