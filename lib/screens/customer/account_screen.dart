import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/motion.dart';
import '../../widgets/security_widgets.dart';
import '../auth/server_sheet.dart';
import 'customer_shell.dart';
import 'extras_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.user;
    if (u == null) return const SizedBox();
    final stays = s.bookings.where((b) => b.status == 'checked_out').length;
    final left = <Widget>[
      AppCard(
        child: Row(children: [
          Avatar(u.name, size: 64, accent: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.name, style: T.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(stays == 0 ? 'Guest account' : 'Guest · ${plural(stays, 'stay')} with us', style: T.bodyMuted),
            ]),
          ),
          Btn('Edit', style: BtnStyle.secondary, expand: false, height: 40, onTap: () => sheet(context, const _EditProfileSheet())),
        ]),
      ),
      const SectionLabel('Contact', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: [
          InfoRow(icon: Icons.mail_outline_rounded, label: 'Email', value: u.email),
          InfoRow(icon: Icons.phone_iphone_rounded, label: 'Mobile', value: u.phone.isEmpty ? 'Not set' : u.phone),
        ]),
      ),
      const SectionLabel('Appearance', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
      const ThemePicker(),
    ];
    final right = <Widget>[
      const SectionLabel('Security', padding: EdgeInsets.fromLTRB(0, 0, 0, 10)),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: [
          InfoRow(icon: Icons.password_rounded, label: 'Signs out your other devices', value: 'Change password', onTap: () => ChangePasswordSheet.open(context)),
          InfoRow(
            icon: Icons.history_toggle_off_rounded,
            label: 'Last sign-in before this one: ${fmtStamp(u.previousLoginAt)}',
            value: 'Recent sign-ins',
            onTap: () => sheet(context, const MyLoginsSheet()),
          ),
        ]),
      ),
      const SectionLabel('More', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: [
          InfoRow(icon: Icons.history_rounded, label: 'All your stays', value: 'Booking history', onTap: () => CustomerShell.goTab(context, 2)),
          InfoRow(icon: Icons.room_service_outlined, label: 'Breakfast, spa, pickup', value: 'Hotel extras', onTap: () => go(context, const ExtrasScreen())),
          InfoRow(icon: Icons.apartment_rounded, label: Hotel.address, value: 'Hotel info', onTap: () => sheet(context, const _HotelInfoSheet())),
          InfoRow(
            icon: Icons.dns_rounded,
            label: s.apiUrl,
            value: 'Database',
            onTap: () => ServerSheet.open(context),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Btn('Log out', style: BtnStyle.danger, icon: Icons.logout_rounded, onTap: () async {
        final ok = await confirmDialog(context, title: 'Log out?', message: 'You can log back in any time.', confirm: 'Log out', danger: true);
        if (ok && context.mounted) await AppScope.read(context).logout();
      }),
    ];
    return Column(children: [
      const PageHeader(title: 'Account', subtitle: 'Manage your details'),
      Expanded(child: SplitList(left: left, right: [const SizedBox(height: 22), ...right], padding: const EdgeInsets.fromLTRB(20, 0, 20, 28))),
    ]);
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet();
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController name, phone;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final u = AppScope.read(context).user!;
    name = TextEditingController(text: u.name);
    phone = TextEditingController(text: u.phone);
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Edit profile', style: T.h2),
          const SizedBox(height: 18),
          Field(label: 'Full name', controller: name),
          Field(label: 'Mobile number', controller: phone, keyboard: TextInputType.phone),
          Btn('Save changes', loading: busy, onTap: () async {
            if (name.text.trim().isEmpty) {
              toast(context, 'Name can\'t be empty', error: true);
              return;
            }
            setState(() => busy = true);
            final ok = await attempt(context, () => AppScope.read(context).updateMe(name: name.text, phone: phone.text),
                success: 'Profile updated');
            if (!context.mounted || !mounted) return;
            setState(() => busy = false);
            if (ok) Navigator.of(context).pop();
          }),
        ]),
      );
}

class _HotelInfoSheet extends StatelessWidget {
  const _HotelInfoSheet();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Logo(size: 30),
          SizedBox(height: 16),
          InfoRow(icon: Icons.place_outlined, label: 'Address', value: Hotel.address),
          InfoRow(icon: Icons.call_outlined, label: 'Front desk · 24 hours', value: Hotel.phone),
          InfoRow(icon: Icons.login_rounded, label: 'Check-in', value: 'From ${Hotel.checkIn}'),
          InfoRow(icon: Icons.logout_rounded, label: 'Check-out', value: 'Until ${Hotel.checkOut}'),
          InfoRow(icon: Icons.payments_outlined, label: 'Payment', value: 'Cash · GCash · Card at the desk'),
        ]),
      );
}
