// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

/// Create / edit the profile. Required: name, age, gender, marital status, marriage details, city, address, education, occupation, mobile.
/// Each contact detail has its own Public / Private switch.
class ProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const ProfileEditScreen({super.key, this.initial});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  static const _keys = ['name', 'age', 'location', 'address', 'education', 'occupation', 'marriage_details', 'children_info', 'family_details',
    'pref_age_min', 'pref_age_max', 'pref_location', 'pref_education', 'pref_occupation', 'phone', 'whatsapp', 'contact_email'];
  static const _labels = {
    'name': 'Full name *', 'age': 'Age *', 'location': 'City / town *', 'address': 'Full address * (only you and the admin can see it)',
    'education': 'Education *', 'occupation': 'Occupation *', 'marriage_details': 'About your previous marriage *',
    'children_info': 'Children * (ages, who they live with)', 'family_details': 'About your family',
    'pref_age_min': 'Preferred age from', 'pref_age_max': 'Preferred age to', 'pref_location': 'Preferred location',
    'pref_education': 'Preferred education', 'pref_occupation': 'Preferred occupation',
    'phone': 'Mobile number *', 'whatsapp': 'WhatsApp number', 'contact_email': 'Contact email',
  };
  static final _phoneRe = RegExp(r'^\+?[0-9]{10,15}$');
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  final _c = {for (final k in _keys) k: TextEditingController()};
  final _e = <String, String?>{};
  String? _gender, _marital, _prefMarital;
  bool _children = false, _private = true, _showPhone = false, _showWa = false, _showEmail = false, _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    if (d != null) {
      for (final k in _keys) { _c[k]!.text = d[k]?.toString() ?? ''; }
      _gender = d['gender'] as String?; _marital = d['marital_status'] as String?; _prefMarital = d['pref_marital_status'] as String?;
      _children = d['has_children'] == true; _private = d['photos_private'] != false;
      _showPhone = d['show_phone'] == true; _showWa = d['show_whatsapp'] == true; _showEmail = d['show_email'] == true;
    }
  }

  String _t(String k) => _c[k]!.text.trim();
  String? _v(String k) => _t(k).isEmpty ? null : _t(k);
  String _digits(String k) => _t(k).replaceAll(RegExp(r'[\s\-]'), '');

  bool _validate() {
    final e = <String, String?>{};
    final age = int.tryParse(_t('age')), pmin = int.tryParse(_t('pref_age_min')), pmax = int.tryParse(_t('pref_age_max'));
    if (_t('name').length < 2) e['name'] = 'Enter your full name.';
    if (age == null || age < 18 || age > 80) e['age'] = 'Age must be between 18 and 80.';
    if (_gender == null) e['gender'] = 'Select your gender.';
    if (_t('location').length < 2) e['location'] = 'Enter your city or town.';
    if (_t('address').length < 8) e['address'] = 'Enter your full address.';
    if (_t('education').length < 2) e['education'] = 'Enter your education.';
    if (_t('occupation').length < 2) e['occupation'] = 'Enter your occupation.';
    if (_marital == null) e['marital'] = 'Select your marital status.';
    if (_t('marriage_details').length < 10) e['marriage_details'] = 'Write a few lines about your marriage (at least 10 characters).';
    if (_children && _t('children_info').length < 2) e['children_info'] = 'Tell us about your children.';
    if (_t('pref_age_min').isNotEmpty && (pmin == null || pmin < 18 || pmin > 80)) e['pref_age_min'] = '18 to 80';
    if (_t('pref_age_max').isNotEmpty && (pmax == null || pmax < 18 || pmax > 80)) e['pref_age_max'] = '18 to 80';
    if (pmin != null && pmax != null && pmin > pmax && e['pref_age_max'] == null) e['pref_age_max'] = 'Must not be less than "from".';
    if (!_phoneRe.hasMatch(_digits('phone'))) e['phone'] = 'Enter a valid mobile number (10 to 15 digits).';
    if (_t('whatsapp').isNotEmpty && !_phoneRe.hasMatch(_digits('whatsapp'))) e['whatsapp'] = 'Enter a valid WhatsApp number.';
    if (_t('contact_email').isNotEmpty && !_emailRe.hasMatch(_t('contact_email'))) e['contact_email'] = 'Enter a valid email address.';
    setState(() { _e..clear()..addAll(e); });
    return e.isEmpty;
  }

  Future<void> _save() async {
    if (!_validate()) {
      snack(context, 'Please fix the highlighted fields.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await Api.call('PUT', '/profile', body: {
        'name': _t('name'), 'age': int.parse(_t('age')), 'gender': _gender, 'location': _t('location'), 'address': _t('address'),
        'education': _t('education'), 'occupation': _t('occupation'), 'marital_status': _marital, 'marriage_details': _t('marriage_details'),
        'has_children': _children, 'children_info': _children ? _v('children_info') : null, 'family_details': _v('family_details'),
        'pref_age_min': int.tryParse(_t('pref_age_min')), 'pref_age_max': int.tryParse(_t('pref_age_max')), 'pref_location': _v('pref_location'),
        'pref_education': _v('pref_education'), 'pref_occupation': _v('pref_occupation'), 'pref_marital_status': _prefMarital,
        'photos_private': _private, 'phone': _digits('phone'), 'whatsapp': _digits('whatsapp'), 'contact_email': _t('contact_email'),
        'show_phone': _showPhone, 'show_whatsapp': _showWa, 'show_email': _showEmail,
      });
      if (!mounted) return;
      snack(context, 'Profile saved.');
      Navigator.pop(context, true);
      return;
    } on ApiError catch (e) {
      if (mounted) snack(context, e.message, error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _f(String k, {int lines = 1, TextInputType? type, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: _c[k], keyboardType: type ?? (lines > 1 ? TextInputType.multiline : TextInputType.text), minLines: lines, maxLines: lines,
          decoration: InputDecoration(labelText: _labels[k], hintText: hint, errorText: _e[k], alignLabelWithHint: lines > 1),
          onChanged: (_) { if (_e[k] != null) setState(() => _e[k] = null); },
        ),
      );

  Widget _contact(String k, bool visible, ValueChanged<bool> onChanged, {TextInputType type = TextInputType.phone}) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        decoration: BoxDecoration(color: Palette.mist, borderRadius: BorderRadius.circular(16), border: Border.all(color: Palette.plum.withOpacity(.25))),
        child: Column(children: [
          TextField(controller: _c[k], keyboardType: type, decoration: InputDecoration(labelText: _labels[k], errorText: _e[k]),
              onChanged: (_) { if (_e[k] != null) setState(() => _e[k] = null); }),
          SwitchListTile(
            value: visible, onChanged: onChanged, activeColor: Palette.plum, contentPadding: EdgeInsets.zero,
            title: Text(visible ? 'Public' : 'Private', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(visible ? 'Every signed-in member can see this.' : 'Only members whose request you accept can see this.', style: const TextStyle(fontSize: 12.5)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, title: Text(widget.initial == null ? 'Create your profile' : 'Edit profile', style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.plum))),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          FormCard('About you', Icons.person_outline, [
            _f('name'), _f('age', type: TextInputType.number),
            Padding(padding: const EdgeInsets.only(bottom: 14), child: Drop('Gender *', _gender, genderOptions, (v) => setState(() { _gender = v; _e['gender'] = null; }), errorText: _e['gender'])),
            _f('location'), _f('address', lines: 2), _f('education'), _f('occupation'),
          ]),
          FormCard('Marriage details', Icons.favorite_border, [
            Padding(padding: const EdgeInsets.only(bottom: 14), child: Drop('Marital status *', _marital, maritalOptions, (v) => setState(() { _marital = v; _e['marital'] = null; }), errorText: _e['marital'])),
            _f('marriage_details', lines: 3, hint: 'For example: married 2012 to 2018, divorce finalised in 2019'),
            SwitchListTile(value: _children, onChanged: (v) => setState(() => _children = v), title: const Text('I have children'), activeColor: Palette.plum, contentPadding: EdgeInsets.zero),
            if (_children) _f('children_info', lines: 2),
            _f('family_details', lines: 2),
          ]),
          FormCard('Looking for (partner preferences)', Icons.search, [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _f('pref_age_min', type: TextInputType.number)), const SizedBox(width: 12), Expanded(child: _f('pref_age_max', type: TextInputType.number)),
            ]),
            _f('pref_location'), _f('pref_education'), _f('pref_occupation'),
            Drop('Preferred marital status', _prefMarital, maritalOptions, (v) => setState(() => _prefMarital = v)),
          ]),
          FormCard('Contact details', Icons.contact_phone_outlined, [
            Container(
              margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Palette.blush, borderRadius: BorderRadius.circular(14)),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, color: Palette.plum, size: 20), SizedBox(width: 8),
                Expanded(child: Text('Choose who can see each detail. Private details are shown only to members who send you a request and whom you accept.', style: TextStyle(fontSize: 13.5))),
              ]),
            ),
            _contact('phone', _showPhone, (v) => setState(() => _showPhone = v)),
            _contact('whatsapp', _showWa, (v) => setState(() => _showWa = v)),
            _contact('contact_email', _showEmail, (v) => setState(() => _showEmail = v), type: TextInputType.emailAddress),
          ]),
          FormCard('Photo privacy', Icons.lock_outline, [
            SwitchListTile(value: _private, onChanged: (v) => setState(() => _private = v), activeColor: Palette.plum, contentPadding: EdgeInsets.zero,
                title: const Text('Keep photos private'), subtitle: const Text('Only members whose interest you accept can see them.')),
          ]),
          AppButton('Save profile', icon: Icons.check_circle_outline, loading: _saving, onPressed: _save),
          const SizedBox(height: 24),
        ]),
      );
}
