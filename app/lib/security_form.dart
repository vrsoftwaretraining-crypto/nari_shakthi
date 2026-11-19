// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';

/// Holds the 3 chosen questions and typed answers.
class SecurityFormController {
  final List<String?> q = [null, null, null];
  final List<TextEditingController> a = List.generate(3, (_) => TextEditingController());
  bool get complete => q.every((e) => e != null) && a.every((c) => c.text.trim().length >= 2);
  List<Map<String, String>> toJson() => [for (var i = 0; i < 3; i++) {'q': q[i]!, 'a': a[i].text}];
}

/// "Choose 3 questions and answer them" box, shared by sign-up and admin creation.
class SecurityQuestionsForm extends StatefulWidget {
  final SecurityFormController ctl;
  const SecurityQuestionsForm(this.ctl, {super.key});
  @override
  State<SecurityQuestionsForm> createState() => _SecurityQuestionsFormState();
}

class _SecurityQuestionsFormState extends State<SecurityQuestionsForm> {
  List<Map<String, dynamic>>? _all;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _err = null);
    try {
      _all = await Api.list('/auth/questions', 'questions');
    } on ApiError catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Palette.blush.withOpacity(.55), borderRadius: BorderRadius.circular(18), border: Border.all(color: Palette.plum.withOpacity(.45), width: 1.4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [
          Icon(Icons.shield_outlined, color: Palette.plum),
          SizedBox(width: 8),
          Expanded(child: Text('Security questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Palette.plumDeep))),
        ]),
        const SizedBox(height: 6),
        const Text('Choose 3 different questions. If you forget your password, answering all 3 correctly lets you set a new one. Remember your answers.',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 14),
        if (_err != null) ...[
          Text(_err!, style: const TextStyle(color: Palette.crimson, fontWeight: FontWeight.w600)),
          TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Try again')),
        ] else if (_all == null)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else
          for (var i = 0; i < 3; i++) ...[
            DropdownButtonFormField<String>(
              value: ctl.q[i], isExpanded: true, decoration: InputDecoration(labelText: 'Question ${i + 1}'),
              items: [
                for (final e in _all!)
                  if (e['id'] == ctl.q[i] || !ctl.q.contains(e['id']))
                    DropdownMenuItem(value: e['id'] as String, child: Text(e['text'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.2))),
              ],
              onChanged: (v) => setState(() => ctl.q[i] = v),
            ),
            const SizedBox(height: 10),
            TextField(controller: ctl.a[i], decoration: InputDecoration(labelText: 'Your answer ${i + 1}', prefixIcon: const Icon(Icons.key_outlined))),
            if (i < 2) const SizedBox(height: 18),
          ],
      ]),
    );
  }
}
