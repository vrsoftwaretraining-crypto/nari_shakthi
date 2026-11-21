// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'admin_insights.dart';
import 'admin_member_screen.dart';
import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});
  @override
  Widget build(BuildContext context) => const DefaultTabController(
        length: 5,
        child: Column(children: [
          Material(color: Colors.white, child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, labelColor: Palette.plum, unselectedLabelColor: Colors.black54, indicatorColor: Palette.marigold, indicatorWeight: 3, tabs: [Tab(text: 'Members'), Tab(text: 'Payments'), Tab(text: 'Reports'), Tab(text: 'Complaints'), Tab(text: 'Payment setup')])),
          Expanded(child: TabBarView(children: [_Members(), _Payments(), AdminInsights(), _Reports(), _PaySetup()])),
        ]),
      );
}

class _Members extends StatefulWidget {
  const _Members();
  @override
  State<_Members> createState() => _MembersState();
}

class _MembersState extends State<_Members> {
  final _key = GlobalKey<AsyncListState>();
  String _status = 'all';

  Future<void> _set(BuildContext c, String id, String s) async {
    var reason = '';
    if (s != 'approved') {
      final r = await askReason(c, title: s == 'rejected' ? 'Reject this member?' : 'Suspend this member?', required: s == 'suspended');
      if (r == null || !c.mounted) return;
      reason = r;
    }
    await _apply(c, id, s, reason);
  }

  Future<void> _apply(BuildContext c, String id, String s, String reason) => guarded(c, () async {
        final m = (await Api.call('POST', '/admin/users/$id/status', body: {'status': s, 'reason': reason}))['message'] as String;
        _key.currentState?.reload();
        return m;
      });

  @override
  Widget build(BuildContext context) => AsyncList(
        key: _key, load: () => Api.list(_status == 'all' ? '/admin/users' : '/admin/users?status=$_status'), emptyText: _status == 'all' ? 'No members have registered yet.' : 'No $_status members.',
        header: Padding(padding: const EdgeInsets.only(bottom: 14), child: Drop('Show', _status,
            const {'all': 'All members', 'pending': 'Pending approval', 'approved': 'Approved', 'rejected': 'Rejected', 'suspended': 'Suspended'}, (v) { _status = v!; _key.currentState?.reload(); })),
        item: (c, m, reload) => MemberTile(
          onTap: () async {
            await Navigator.push(c, MaterialPageRoute(builder: (_) => AdminMemberScreen(id: m['id'] as String)));
            _key.currentState?.reload();
          },
          title: '${m['name'] ?? 'Profile not completed'}${m['age'] != null ? ', ${m['age']}' : ''}',
          subtitle: '${m['email']}\n${m['location'] ?? ''}', badge: '${m['status']}',
          actions: [
            // Only the buttons that make sense for the member's current status
            if (m['status'] != 'approved') TileButton('Approve', icon: Icons.check, kind: BtnKind.success, onPressed: () => _set(c, m['id'], 'approved')),
            if (m['status'] == 'pending') TileButton('Reject', icon: Icons.close, kind: BtnKind.secondary, onPressed: () => _set(c, m['id'], 'rejected')),
            if (m['status'] == 'approved' || m['status'] == 'pending') TileButton('Suspend', icon: Icons.block, kind: BtnKind.danger, onPressed: () => _set(c, m['id'], 'suspended')),
          ],
        ),
      );
}

class _Payments extends StatefulWidget {
  const _Payments();
  @override
  State<_Payments> createState() => _PaymentsState();
}

class _PaymentsState extends State<_Payments> {
  final _key = GlobalKey<AsyncListState>();
  String _status = 'all';
  static const _filters = {'all': 'All payments', 'pending': 'Waiting for verification', 'verified': 'Verified', 'rejected': 'Rejected'};

  Future<void> _decide(BuildContext c, Map<String, dynamic> m, bool ok) async {
    final amt = TextEditingController(text: m['amount_rupees']?.toString() ?? ''), note = TextEditingController();
    final go = await showDialog<bool>(
      context: c,
      builder: (ctx) => AlertDialog(
        title: Text(ok ? 'Verify this payment?' : 'Reject this payment?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (ok) ...[
            TextField(controller: amt, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount received (₹)', prefixIcon: Icon(Icons.currency_rupee))),
            const SizedBox(height: 12),
          ],
          TextField(controller: note, maxLines: 2, decoration: InputDecoration(labelText: ok ? 'Note (optional)' : 'Reason (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok ? 'Verify' : 'Reject', style: TextStyle(color: ok ? Colors.green.shade800 : Palette.crimson, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (go != true || !c.mounted) return;
    await guarded(c, () async {
      final a = int.tryParse(amt.text.trim());
      final msg = (await Api.call('POST', '/admin/payments/${m['id']}/verify', body: {'approve': ok, 'note': note.text.trim(), if (ok && a != null) 'amount_rupees': a}))['message'] as String;
      _key.currentState?.reload();
      return msg;
    });
  }

  String _t(Object? v) => '$v'.split('.').first;

  @override
  Widget build(BuildContext context) => AsyncList(
        key: _key,
        load: () => Api.list('/admin/payments?status=$_status'),
        emptyText: 'No payments here yet.',
        header: Padding(padding: const EdgeInsets.only(bottom: 12), child: Drop('Show', _status, _filters, (v) { _status = v!; _key.currentState?.reload(); })),
        item: (c, m, reload) {
          final st = m['status'] as String;
          final lines = [
            '${m['email']}',
            '${m['method'] == 'razorpay' ? 'Razorpay (online)' : 'UPI screenshot'}${m['amount_rupees'] != null ? '  •  ₹${m['amount_rupees']}' : ''}',
            if (m['txn_ref'] != null) 'Transaction ID: ${m['txn_ref']}',
            'Paid on: ${_t(m['created_at'])}',
            if (m['verified_at'] != null) '${st == 'rejected' ? 'Rejected' : 'Verified'} on: ${_t(m['verified_at'])}${m['verified_by_email'] != null ? ' by ${m['verified_by_email']}' : ''}',
            if (m['admin_note'] != null) 'Note: ${m['admin_note']}',
          ];
          return MemberTile(
            title: '${m['name'] ?? m['email']}', subtitle: lines.join('\n'),
            badge: {'pending': 'Waiting for verification', 'verified': 'Verified', 'rejected': 'Rejected'}[st],
            actions: [
              if (m['has_screenshot'] == true)
                TileButton('Screenshot', icon: Icons.image_outlined, kind: BtnKind.secondary, onPressed: () => showDialog(context: c, builder: (_) => Dialog(
                    child: InteractiveViewer(child: Image.network('$apiBase/admin/payments/${m['id']}/screenshot', headers: Api.authHeaders,
                        errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(24), child: Text('Could not load the screenshot.'))))))),
              if (st == 'pending') ...[
                TileButton('Verify', icon: Icons.verified_outlined, kind: BtnKind.success, onPressed: () => _decide(c, m, true)),
                TileButton('Reject', icon: Icons.close, kind: BtnKind.danger, onPressed: () => _decide(c, m, false)),
              ],
            ],
          );
        },
      );
}

class _Reports extends StatefulWidget {
  const _Reports();
  @override
  State<_Reports> createState() => _ReportsState();
}

class _ReportsState extends State<_Reports> {
  final _key = GlobalKey<AsyncListState>();
  static const _why = {'fake_profile': 'Fake profile', 'harassment': 'Harassment', 'inappropriate_content': 'Inappropriate content', 'asking_for_money': 'Asking for money', 'other': 'Other'};

  Future<void> _resolve(BuildContext c, dynamic id, String action) => guarded(c, () async {
        final m = (await Api.call('POST', '/admin/reports/$id/resolve', body: {'action': action}))['message'] as String;
        _key.currentState?.reload();
        return m;
      });

  @override
  Widget build(BuildContext context) => AsyncList(
        key: _key, load: () => Api.list('/admin/reports?status=open'), emptyText: 'No open reports.',
        item: (c, m, reload) => MemberTile(
          title: '${m['target_name'] ?? m['target_email']}', badge: '${_why[m['reason']] ?? m['reason']} • ${m['report_count']} report(s) in total',
          subtitle: '${m['target_email']} (${m['target_status']})${m['details'] != null ? '\n"${m['details']}"' : ''}',
          actions: [
            TileButton('Dismiss', icon: Icons.close, kind: BtnKind.secondary, onPressed: () => _resolve(c, m['id'], 'dismiss')),
            TileButton('Suspend', icon: Icons.block, kind: BtnKind.danger, onPressed: () => _resolve(c, m['id'], 'suspend')),
          ],
        ),
      );
}

/// Payment setup: shows what is saved (members see exactly this), with Edit and Delete.
class _PaySetup extends StatefulWidget {
  const _PaySetup();
  @override
  State<_PaySetup> createState() => _PaySetupState();
}

class _PaySetupState extends State<_PaySetup> {
  final _name = TextEditingController(), _upi = TextEditingController(), _amt = TextEditingController();
  bool _loading = true, _saving = false, _hasQr = false, _razorpay = false, _editing = false;
  int _ver = 0;
  String? _eName, _eUpi, _eAmt, _eQr;
  static final _upiRe = RegExp(r'^[A-Za-z0-9._\-]{2,}@[A-Za-z][A-Za-z0-9]{1,}$');

  bool _validate() {
    final name = _name.text.trim(), upi = _upi.text.trim(), amt = int.tryParse(_amt.text.trim());
    _eName = name.length < 2 ? 'Enter the payee name.' : (name.length > 60 ? 'The name is too long (60 characters at most).' : null);
    _eUpi = upi.isEmpty ? 'Enter the UPI ID.' : (_upiRe.hasMatch(upi) ? null : 'Enter a valid UPI ID, like name@bank.');
    _eAmt = amt == null ? 'Enter the amount in rupees.' : ((amt < 1 || amt > 100000) ? 'Amount must be between 1 and 100000.' : null);
    _eQr = _hasQr ? null : 'Upload the payment QR code.';
    setState(() {});
    return _eName == null && _eUpi == null && _eAmt == null && _eQr == null;
  }

  bool get _has => _name.text.isNotEmpty || _upi.text.isNotEmpty || _amt.text.isNotEmpty || _hasQr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.call('GET', '/payment-info');
      _name.text = d['payee_name'] as String? ?? '';
      _upi.text = d['upi_id'] as String? ?? '';
      _amt.text = d['amount_rupees']?.toString() ?? '';
      _hasQr = d['has_qr'] == true;
      _razorpay = d['razorpay'] == true;
      _ver = (d['version'] as num?)?.toInt() ?? 0;
      if (_hasQr) _eQr = null;
    } on ApiError catch (e) {
      if (mounted) snack(context, e.message, error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    var ok = false;
    await guarded(context, () async {
      final m = (await Api.call('PUT', '/admin/payment-settings', body: {'upi_id': _upi.text, 'payee_name': _name.text, 'amount_rupees': int.tryParse(_amt.text.trim())}))['message'] as String;
      await _load();
      ok = true;
      return m;
    });
    if (mounted) setState(() { _saving = false; if (ok) _editing = false; });
  }

  Future<void> _uploadQr() => guarded(context, () async {
        final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
        if (f == null) return null;
        final m = await Api.upload('/admin/payment-settings/qr', f);
        await _load();
        return m;
      });

  Future<void> _removeQr() => guarded(context, () async {
        final m = (await Api.call('DELETE', '/admin/payment-settings/qr'))['message'] as String;
        await _load();
        return m;
      });

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('Delete payment details?'),
        content: const Text('The UPI ID, name, amount and QR code will be removed. Members will no longer see them.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Palette.crimson, fontWeight: FontWeight.w800)))]));
    if (ok != true || !mounted) return;
    await guarded(context, () async {
      final m = (await Api.call('DELETE', '/admin/payment-settings'))['message'] as String;
      await _load();
      return m;
    });
  }

  Widget _qrImage() => ClipRRect(borderRadius: BorderRadius.circular(14),
      child: Image.network('$apiBase/payment-info/qr?v=$_ver', headers: Api.authHeaders, height: 240, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text('Could not load the QR code.')));

  Widget _line(String label, String v) => v.isEmpty ? const SizedBox.shrink() : Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.black54))),
        Expanded(child: SelectableText(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
      ]));

  Widget _razorpayNote() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Palette.blush, borderRadius: BorderRadius.circular(16), border: Border.all(color: Palette.plum.withOpacity(.4), width: 1.2)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_razorpay ? Icons.check_circle : Icons.info_outline, color: _razorpay ? Colors.green : Palette.plum),
          const SizedBox(width: 10),
          Expanded(child: Text(_razorpay ? 'Razorpay online payment is ON. Members see a "Pay online" button.'
              : 'Razorpay online payment is OFF. It turns on when the Razorpay keys are set on the server and an amount is saved.', style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_editing && !_has) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        const EmptyState(Icons.account_balance_wallet_outlined, 'No payment details added yet.'),
        AppButton('Add payment details', icon: Icons.add, onPressed: () => setState(() => _editing = true)),
      ]);
    }
    if (!_editing) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        FormCard('Saved payment details', Icons.account_balance_wallet_outlined, [
          _line('Payee', _name.text), _line('UPI ID', _upi.text), _line('Amount', _amt.text.isEmpty ? '' : '₹${_amt.text}'),
          if (_hasQr) Padding(padding: const EdgeInsets.only(top: 4), child: Center(child: _qrImage())),
        ]),
        Row(children: [
          Expanded(child: AppButton('Edit', icon: Icons.edit_outlined, onPressed: () => setState(() => _editing = true))),
          const SizedBox(width: 12),
          Expanded(child: AppButton('Delete', icon: Icons.delete_outline, kind: BtnKind.danger, onPressed: _deleteAll)),
        ]),
        const SizedBox(height: 16),
        _razorpayNote(),
        const SizedBox(height: 24),
      ]);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      FormCard('Edit payment details', Icons.edit_outlined, [
        TextField(controller: _name, decoration: InputDecoration(labelText: 'Payee name *', prefixIcon: const Icon(Icons.badge_outlined), errorText: _eName)),
        const SizedBox(height: 14),
        TextField(controller: _upi, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'UPI ID * (name@bank)', prefixIcon: const Icon(Icons.alternate_email), errorText: _eUpi)),
        const SizedBox(height: 14),
        TextField(controller: _amt, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Membership amount (₹) *', prefixIcon: const Icon(Icons.currency_rupee), errorText: _eAmt)),
      ]),
      FormCard('Payment QR code *', Icons.qr_code_2, [
        if (_eQr != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_eQr!, style: const TextStyle(color: Palette.crimson, fontWeight: FontWeight.w700))),
        if (_hasQr) Padding(padding: const EdgeInsets.only(bottom: 14), child: Center(child: _qrImage())),
        AppButton(_hasQr ? 'Change QR code' : 'Upload QR code', icon: Icons.upload_file, kind: BtnKind.secondary, onPressed: _uploadQr),
        if (_hasQr) ...[const SizedBox(height: 10), AppButton('Remove QR code', icon: Icons.delete_outline, kind: BtnKind.danger, onPressed: _removeQr)],
      ]),
      AppButton('Save', icon: Icons.check_circle_outline, loading: _saving, onPressed: _save),
      const SizedBox(height: 10),
      if (_has) AppButton('Cancel', kind: BtnKind.secondary, onPressed: () async { setState(() => _loading = true); await _load(); if (mounted) setState(() => _editing = false); }),
      const SizedBox(height: 24),
    ]);
  }
}
