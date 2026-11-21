// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Admin Reports: weekly / monthly numbers, marriage reports, and the monthly member list (with CSV copy).
class AdminInsights extends StatefulWidget {
  const AdminInsights({super.key});
  @override
  State<AdminInsights> createState() => _AdminInsightsState();
}

class _AdminInsightsState extends State<AdminInsights> {
  String _period = 'week';
  Map<String, dynamic>? _d;
  List<Map<String, dynamic>> _marriages = [];
  List<Map<String, dynamic>>? _members;
  bool _loading = true, _loadingMembers = false;
  late final Map<String, String> _months = {
    for (var i = 0; i < 12; i++)
      '${DateTime(DateTime.now().year, DateTime.now().month - i, 1).year}-${DateTime(DateTime.now().year, DateTime.now().month - i, 1).month.toString().padLeft(2, '0')}':
          '${_monthNames[DateTime(DateTime.now().year, DateTime.now().month - i, 1).month - 1]} ${DateTime(DateTime.now().year, DateTime.now().month - i, 1).year}',
  };
  late String _month = _months.keys.first;

  @override
  void initState() {
    super.initState();
    _load();
    _loadMembers();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _d = await Api.call('GET', '/admin/insights?period=$_period');
      _marriages = await Api.list('/admin/marriages');
    } on ApiError catch (e) {
      if (mounted) snack(context, e.message, error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      _members = await Api.list('/admin/reports/members?month=$_month');
    } on ApiError catch (e) {
      if (mounted) snack(context, e.message, error: true);
    }
    if (mounted) setState(() => _loadingMembers = false);
  }

  Future<void> _decide(String id, bool ok) => guarded(context, () async {
        final m = (await Api.call('POST', '/admin/marriages/$id/decide', body: {'confirm': ok}))['message'] as String;
        await _load();
        return m;
      });

  String _label(String start) {
    final y = start.substring(0, 4), mo = int.parse(start.substring(5, 7)), day = start.substring(8, 10);
    return _period == 'month' ? '${_monthNames[mo - 1]} $y' : '$day ${_monthNames[mo - 1]}';
  }

  Widget _stat(IconData i, String label, Object value) => Container(
        width: 150, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Palette.plum.withOpacity(.18)),
            boxShadow: [BoxShadow(color: Palette.plum.withOpacity(.06), blurRadius: 12, offset: const Offset(0, 5))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, color: Palette.plum, size: 22), const SizedBox(height: 8),
          Text('$value', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Palette.plumDeep)),
          Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
        ]),
      );

  Widget _bars(List<Map<String, dynamic>> rows, String key, Color color) {
    final maxV = rows.fold<int>(1, (a, r) => (r[key] as int) > a ? r[key] as int : a);
    return Column(children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(width: 74, child: Text(_label(r['start'] as String), style: const TextStyle(fontSize: 12.5, color: Colors.black54))),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: (r[key] as int) / maxV, minHeight: 14, backgroundColor: Palette.mist, color: color))),
            SizedBox(width: 40, child: Text('${r[key]}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
        ),
    ]);
  }

  String _esc(Object? v) {
    final s = '${v ?? ''}';
    return (s.contains(',') || s.contains('"') || s.contains('\n')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  String _csv(List<Map<String, dynamic>> items) {
    const head = ['Name', 'Email', 'Mobile', 'Age', 'Gender', 'City', 'Marital status', 'Education', 'Occupation', 'Status', 'Joined', 'Interests sent', 'Interests received', 'Connections', 'Profile views'];
    final lines = [head.join(',')];
    for (final m in items) {
      lines.add([m['name'], m['email'], m['phone'], m['age'], genderOptions[m['gender']] ?? m['gender'], m['location'], maritalOptions[m['marital_status']] ?? m['marital_status'],
        m['education'], m['occupation'], m['status'], m['joined'], m['interests_sent'], m['interests_received'], m['connections'], m['profile_views']].map(_esc).join(','));
    }
    return lines.join('\n');
  }

  Widget _table(List<Map<String, dynamic>> rows) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18, headingRowHeight: 46, dataRowMinHeight: 40, dataRowMaxHeight: 44,
          headingTextStyle: const TextStyle(fontWeight: FontWeight.w800, color: Palette.plumDeep, fontSize: 12.5),
          columns: const [
            DataColumn(label: Text('Period')), DataColumn(label: Text('New\nmembers'), numeric: true), DataColumn(label: Text('Profile\nviews'), numeric: true),
            DataColumn(label: Text('Unique\nviewers'), numeric: true), DataColumn(label: Text('Interests\nsent'), numeric: true), DataColumn(label: Text('Mutual\n(accepted)'), numeric: true),
            DataColumn(label: Text('Contact\nrequests'), numeric: true), DataColumn(label: Text('Contacts\nshared'), numeric: true), DataColumn(label: Text('Marriages'), numeric: true),
            DataColumn(label: Text('Payments\n(₹)'), numeric: true),
          ],
          rows: [
            for (final r in rows)
              DataRow(cells: [
                DataCell(Text(_label(r['start'] as String), style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(Text('${r['registrations']}')), DataCell(Text('${r['profile_views']}')), DataCell(Text('${r['viewers']}')), DataCell(Text('${r['interests_sent']}')),
                DataCell(Text('${r['interests_accepted']}')), DataCell(Text('${r['contact_requests']}')), DataCell(Text('${r['contacts_shared']}')), DataCell(Text('${r['marriages']}')),
                DataCell(Text('${r['payment_amount']}')),
              ]),
          ],
        ),
      );

  Widget _count(String label, int n) => Chip(label: Text('$label: $n'), backgroundColor: Palette.mist, side: BorderSide(color: Palette.plum.withOpacity(.2)), visualDensity: VisualDensity.compact);

  @override
  Widget build(BuildContext context) {
    if (_loading && _d == null) return const Center(child: CircularProgressIndicator());
    final d = _d;
    if (d == null) return const EmptyState(Icons.info_outline, 'Could not load the reports.');
    final rows = (d['rows'] as List).cast<Map<String, dynamic>>(), t = d['totals'] as Map<String, dynamic>;
    final ms = _members ?? const <Map<String, dynamic>>[];
    int c(bool Function(Map<String, dynamic>) f) => ms.where(f).length;
    return RefreshIndicator(
      onRefresh: () async { await _load(); await _loadMembers(); },
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          _stat(Icons.groups_outlined, 'Members', t['members']), _stat(Icons.verified_user_outlined, 'Approved', t['approved']), _stat(Icons.hourglass_top, 'Waiting approval', t['pending']),
          _stat(Icons.block, 'Suspended', t['suspended']), _stat(Icons.favorite, 'Marriages confirmed', t['marriages']), _stat(Icons.currency_rupee, 'Payments verified (₹)', t['payment_amount']),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'week', label: Text('Weekly'), icon: Icon(Icons.view_week_outlined)), ButtonSegment(value: 'month', label: Text('Monthly'), icon: Icon(Icons.calendar_month_outlined))],
            selected: {_period}, onSelectionChanged: (v) { _period = v.first; _load(); },
          )),
        ]),
        const SizedBox(height: 16),
        FormCard(_period == 'week' ? 'Last 8 weeks' : 'Last 12 months', Icons.table_chart_outlined, [_table(rows)]),
        FormCard('New members', Icons.person_add_alt_1, [_bars(rows, 'registrations', Palette.plum)]),
        FormCard('Profile views', Icons.visibility_outlined, [_bars(rows, 'profile_views', Palette.marigold)]),
        FormCard('Mutual connections (interest accepted)', Icons.handshake_outlined, [_bars(rows, 'interests_accepted', Palette.crimson)]),
        FormCard('Marriage reports', Icons.favorite_border, [
          if (_marriages.isEmpty) const Text('No marriage reports yet. Members report a marriage from their Inbox, and you confirm it here.', style: TextStyle(color: Colors.black54)),
          for (final m in _marriages)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m['names']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text('Reported ${'${m['reported_at']}'.split('.').first}  •  ${m['status']}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                if (m['status'] == 'reported') ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 10, children: [
                    TileButton('Confirm marriage', icon: Icons.favorite, kind: BtnKind.success, onPressed: () => _decide(m['id'] as String, true)),
                    TileButton('Reject', icon: Icons.close, kind: BtnKind.danger, onPressed: () => _decide(m['id'] as String, false)),
                  ]),
                ],
              ]),
            ),
        ]),
        FormCard('Monthly member report', Icons.assignment_outlined, [
          Drop('Month', _month, _months, (v) { _month = v!; _loadMembers(); }),
          const SizedBox(height: 14),
          if (_loadingMembers) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else ...[
            Wrap(spacing: 8, runSpacing: 4, children: [
              _count('Registered', ms.length), _count('Approved', c((m) => m['status'] == 'approved')), _count('Pending', c((m) => m['status'] == 'pending')),
              _count('Women', c((m) => m['gender'] == 'female')), _count('Men', c((m) => m['gender'] == 'male')),
              _count('Divorced', c((m) => m['marital_status'] == 'divorced')), _count('Widowed', c((m) => m['marital_status'] == 'widowed')),
              _count('Legally separated', c((m) => m['marital_status'] == 'legally_separated')),
            ]),
            const SizedBox(height: 14),
            if (ms.isEmpty) const Text('No members registered in this month.', style: TextStyle(color: Colors.black54))
            else ...[
              for (final m in ms)
                Container(
                  margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Palette.mist.withOpacity(.6), borderRadius: BorderRadius.circular(14), border: Border.all(color: Palette.plum.withOpacity(.15))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${m['name'] ?? 'Profile not completed'}${m['age'] != null ? ', ${m['age']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${m['email']}  •  ${m['status']}  •  joined ${m['joined']}', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                    Text([m['location'], maritalOptions[m['marital_status']], m['occupation']].where((e) => e != null && '$e'.isNotEmpty).join('  •  '), style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Sent ${m['interests_sent']}  •  Received ${m['interests_received']}  •  Connected ${m['connections']}  •  Views ${m['profile_views']}',
                        style: const TextStyle(fontSize: 12.5, color: Palette.plum, fontWeight: FontWeight.w600)),
                  ]),
                ),
              const SizedBox(height: 6),
              AppButton('Copy report as CSV (open in Excel)', icon: Icons.copy_all, kind: BtnKind.secondary, onPressed: () { Clipboard.setData(ClipboardData(text: _csv(ms))); snack(context, 'Copied. Paste it into Excel or Google Sheets.'); }),
            ],
          ],
        ]),
        const SizedBox(height: 24),
      ]),
    );
  }
}
