// Developed by Codesoftwares
import 'package:flutter/material.dart';
import 'admin_screen.dart';
import 'api.dart';
import 'inbox_screen.dart';
import 'payment_screen.dart';
import 'profile_screen.dart';
import 'screen_guard.dart';
import 'change_password_screen.dart';
import 'search_screen.dart';
import 'setup_admin_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class Home extends StatefulWidget {
  final VoidCallback onSignedOut;
  const Home({super.key, required this.onSignedOut});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    ScreenGuard.set(true); // photos must not be screenshotted or recorded
  }

  @override
  void dispose() {
    ScreenGuard.set(false);
    super.dispose();
  }

  static const _msgs = {
    'marriage_confirmed': 'Congratulations! Your marriage has been confirmed.', 'contact_request': 'Someone requested your contact details.', 'contact_accepted': 'Your contact request was accepted.',
    'interest_received': 'Someone sent you an interest.', 'interest_accepted': 'Your interest was accepted.',
    'message_received': 'You have a new message.', 'profile_approved': 'Your profile was approved.', 'profile_rejected': 'Your profile was not approved.',
    'profile_suspended': 'Your account was suspended.', 'payment_verified': 'Your payment was verified.', 'payment_rejected': 'Your payment could not be verified.',
  };

  Future<void> _notifications() async {
    await guarded(context, () async {
      final items = await Api.list('/notifications');
      if (!mounted) return null;
      await showModalBottomSheet(context: context, showDragHandle: true, builder: (_) => ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (items.isEmpty) const EmptyState(Icons.notifications_none, 'Nothing new yet.'),
            for (final n in items) ListTile(leading: Icon(Icons.circle, size: 12, color: n['read'] == true ? Colors.black26 : Palette.marigold), title: Text(_msgs[n['kind']] ?? 'New update.')),
          ]));
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = Api.role, admin = role == 'admin' || role == 'setup'; // staff accounts never see member screens
    // Admin sees ONLY the admin panel. Members never see it.
    final tabs = <(String, IconData, Widget)>[
      if (role == 'admin')
        ('Admin Panel', Icons.admin_panel_settings_outlined, const AdminScreen())
      else if (role == 'setup')
        ('Create Admin', Icons.admin_panel_settings_outlined, SetupAdminScreen(onDone: widget.onSignedOut))
      else ...[
        ('Search', Icons.search, const SearchScreen()),
        ('Inbox', Icons.mark_email_unread_outlined, const InboxScreen()),
        ('Shortlist', Icons.star_outline, const ShortlistScreen()),
        ('Profile', Icons.person_outline, const ProfileScreen()),
        ('Payment', Icons.account_balance_wallet_outlined, const PaymentScreen()),
      ],
    ];
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(tabs[_i].$1, style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.plum)),
          actions: [if (!admin) IconButton(tooltip: 'Notifications', icon: const Icon(Icons.notifications_none), onPressed: _notifications),
                    if (role != 'setup') IconButton(tooltip: 'Change password', icon: const Icon(Icons.lock_reset), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
                    IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: widget.onSignedOut)]),
      body: IndexedStack(index: _i, children: [for (final t in tabs) t.$3]),
      bottomNavigationBar: admin ? null : NavigationBar(
        selectedIndex: _i, backgroundColor: Colors.white.withOpacity(.92), indicatorColor: Palette.mist,
        onDestinationSelected: (i) {
          setState(() => _i = i);
          ScreenGuard.set(tabs[i].$1 != 'Payment'); // members may screenshot the payment QR to pay from their UPI app
        },
        destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.$2), label: t.$1)]),
    );
  }
}
