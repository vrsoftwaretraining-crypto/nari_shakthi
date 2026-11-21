// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'api.dart';
import 'member_profile_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class SearchScreen extends StatefulWidget {
  final VoidCallback? onNeedLogin; // set when the visitor is not signed in (public mode)
  const SearchScreen({super.key, this.onNeedLogin});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _key = GlobalKey<AsyncListState>();
  final _min = TextEditingController(), _max = TextEditingController(), _loc = TextEditingController();
  String? _gender, _marital;
  bool get _public => widget.onNeedLogin != null;

  Future<List<Map<String, dynamic>>> _load() {
    final p = {'gender': _gender, 'marital_status': _marital, 'age_min': _min.text, 'age_max': _max.text, 'location': _loc.text}
      ..removeWhere((k, v) => v == null || v.isEmpty);
    return Api.list('${_public ? '/public/search' : '/search'}?${Uri(queryParameters: p.cast<String, String>()).query}', 'results');
  }

  @override
  Widget build(BuildContext context) => AsyncList(
        key: _key, load: _load, emptyText: 'No matches yet. Try widening the filters.',
        header: Card(
          color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
            if (_public) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Palette.blush, borderRadius: BorderRadius.circular(14), border: Border.all(color: Palette.plum.withOpacity(.4))),
                child: const Row(children: [
                  Icon(Icons.lock_outline, color: Palette.plum),
                  SizedBox(width: 10),
                  Expanded(child: Text('Photos, interests and chat are available after you sign in.', style: TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            Drop('Looking for', _gender, genderOptions, (v) => _gender = v),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age from'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age to'))),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _loc, decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.place_outlined))),
            const SizedBox(height: 12),
            Drop('Marital status', _marital, maritalOptions, (v) => _marital = v),
            const SizedBox(height: 14),
            AppButton('Find matches', icon: Icons.search, onPressed: () => _key.currentState?.reload()),
          ])),
        ),
        item: (c, m, reload) => MemberTile(
          onTap: _public ? null : () => openMember(c, m['user_id'] as String?),
          memberId: m['user_id'] as String?, photoId: _public ? null : m['photo_id'] as String?, title: '${m['name']}, ${m['age']}',
          subtitle: [m['occupation'], m['location']].where((e) => e != null && '$e'.isNotEmpty).join(' • '),
          badge: maritalOptions[m['marital_status']],
          actions: _public
              ? [TileButton('Sign in to connect', icon: Icons.lock_open, onPressed: widget.onNeedLogin)]
              : [
                  TileButton('Send interest', icon: Icons.favorite_border, onPressed: () => guarded(c, () async => (await Api.call('POST', '/interests/${m['user_id']}'))['message'] as String)),
                  TileButton('Shortlist', icon: Icons.star_border, kind: BtnKind.secondary, onPressed: () => guarded(c, () async => (await Api.call('PUT', '/shortlist/${m['user_id']}'))['message'] as String)),
                ],
        ),
      );
}
