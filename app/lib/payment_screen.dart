// Developed by Codesoftwares
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

/// Members pay either online (Razorpay) or by UPI/QR + screenshot. UPI ID, name, amount and QR are set by the admin.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _key = GlobalKey<AsyncListState>();
  Razorpay? _rz;
  Map<String, dynamic>? _info;
  String? _infoErr;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _rz = Razorpay()
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess)
        ..on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    }
    _loadInfo();
  }

  @override
  void dispose() {
    _rz?.clear();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    try {
      _info = await Api.call('GET', '/payment-info');
      _infoErr = null;
    } on ApiError catch (e) {
      _infoErr = e.message;
    }
    if (mounted) setState(() {});
  }

  Future<void> _upload() async {
    final amt = TextEditingController(text: _info?['amount_rupees']?.toString() ?? ''), ref = TextEditingController();
    String? err;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Payment details'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Enter what you paid. The admin checks it against your screenshot.'),
            const SizedBox(height: 14),
            TextField(controller: amt, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Amount paid (₹) *', errorText: err, prefixIcon: const Icon(Icons.currency_rupee))),
            const SizedBox(height: 12),
            TextField(controller: ref, decoration: const InputDecoration(labelText: 'UPI transaction ID (optional)', prefixIcon: Icon(Icons.tag))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final a = int.tryParse(amt.text.trim());
                if (a == null || a < 1 || a > 100000) { set(() => err = 'Enter the amount in rupees.'); return; }
                Navigator.pop(ctx, true);
              },
              child: const Text('Choose screenshot', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await guarded(context, () async {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
      if (f == null) return null;
      final m = await Api.upload('/payments', f, extra: {'amount_rupees': int.parse(amt.text.trim()), if (ref.text.trim().isNotEmpty) 'txn_ref': ref.text.trim()});
      _key.currentState?.reload();
      return m;
    });
  }

  // Online payment: server creates the order -> Razorpay checkout -> server verifies the signature.
  Future<void> _payOnline() async {
    setState(() => _paying = true);
    await guarded(context, () async {
      final o = await Api.call('POST', '/payments/razorpay/order');
      _rz!.open({
        'key': o['key_id'], 'amount': o['amount_paise'], 'currency': 'INR', 'order_id': o['order_id'],
        'name': 'Nari Shakthi Matrimony', 'description': 'Membership', 'theme': {'color': '#8E1B4D'},
      });
      return null;
    });
    if (mounted) setState(() => _paying = false);
  }

  Future<void> _onSuccess(PaymentSuccessResponse r) async {
    if (!mounted) return;
    await guarded(context, () async {
      final m = (await Api.call('POST', '/payments/razorpay/verify',
          body: {'razorpay_order_id': r.orderId, 'razorpay_payment_id': r.paymentId, 'razorpay_signature': r.signature}))['message'] as String;
      _key.currentState?.reload();
      return m;
    });
  }

  void _onError(PaymentFailureResponse r) {
    if (mounted) snack(context, r.message == null || r.message!.isEmpty ? 'Payment was cancelled.' : r.message!, error: true);
  }

  Widget _upiCard(Map<String, dynamic> i) {
    final upi = i['upi_id'] as String?, name = i['payee_name'] as String?, amount = i['amount_rupees'];
    if (upi == null && i['has_qr'] != true) {
      return const FormCard('Pay by UPI / QR', Icons.qr_code_2, [Text('The admin has not added the payment details yet. Please check back soon.')]);
    }
    return FormCard('Pay by UPI / QR', Icons.qr_code_2, [
      if (amount != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('Amount: ₹$amount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Palette.plumDeep))),
      if (name != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('Pay to: $name', style: const TextStyle(fontWeight: FontWeight.w700))),
      if (upi != null)
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(color: Palette.mist, borderRadius: BorderRadius.circular(14), border: Border.all(color: Palette.plum.withOpacity(.4), width: 1.2)),
          child: Row(children: [
            Expanded(child: SelectableText(upi, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            IconButton(tooltip: 'Copy', icon: const Icon(Icons.copy), onPressed: () { Clipboard.setData(ClipboardData(text: upi)); snack(context, 'UPI ID copied.'); }),
          ]),
        ),
      if (i['has_qr'] == true) Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Center(child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Container(color: Colors.white, padding: const EdgeInsets.all(8),
            child: Image.network('$apiBase/payment-info/qr?v=${i['version']}', headers: Api.authHeaders, height: 240, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(16), child: Text('Could not load the QR code.')))))),
      ),
      const SizedBox(height: 14),
      const Text('After paying, upload a screenshot of the payment. An admin will verify it and you will get a notification.'),
      const SizedBox(height: 12),
      AppButton('Upload payment screenshot', icon: Icons.upload_file, kind: BtnKind.secondary, onPressed: _upload),
    ]);
  }

  Widget _header() {
    final i = _info;
    if (i == null) {
      return _infoErr == null
          ? const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          : EmptyState(Icons.info_outline, _infoErr!);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (i['razorpay'] == true && !kIsWeb)
        FormCard('Pay online', Icons.bolt, [
          Text('Pay ₹${i['amount_rupees']} securely with UPI, cards or net banking (Razorpay). Your membership is confirmed right away.'),
          const SizedBox(height: 14),
          AppButton('Pay ₹${i['amount_rupees']} now', icon: Icons.lock_outline, loading: _paying, onPressed: _payOnline),
        ]),
      _upiCard(i),
    ]);
  }

  @override
  Widget build(BuildContext context) => AsyncList(
        key: _key, load: () => Api.list('/payments/mine'), emptyText: 'No payments yet.', header: _header(),
        item: (c, m, reload) => MemberTile(
            title: m['method'] == 'razorpay' ? 'Online payment${m['amount_paise'] != null ? ' ₹${(m['amount_paise'] as int) ~/ 100}' : ''}' : 'UPI payment${m['amount_paise'] != null ? ' ₹${(m['amount_paise'] as int) ~/ 100}' : ''}',
            subtitle: '${m['created_at']}'.split('.').first,
            badge: {'pending': 'Waiting for admin', 'verified': 'Verified', 'rejected': 'Rejected, upload again'}[m['status']]),
      );
}
