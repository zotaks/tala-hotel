import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/security_widgets.dart';
import 'account_screen.dart';
import 'bookings_screen.dart';
import 'home_screen.dart';
import 'rooms_screen.dart';
import 'saved_screen.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  /// Lets any screen switch tabs, e.g. Home → "See all" rooms.
  static void goTab(BuildContext context, int i) => context.findAncestorStateOfType<CustomerShellState>()?.setTab(i);

  @override
  State<CustomerShell> createState() => CustomerShellState();
}

class CustomerShellState extends State<CustomerShell> {
  int index = 0;
  void setTab(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    const tabs = [HomeScreen(), RoomsScreen(), BookingsScreen(), SavedScreen(), AccountScreen()];
    return ShellScaffold(
      index: index,
      onTap: setTab,
      railFooter: const ThemeToggleButton(),
      items: [
        const NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
        const NavItem(Icons.bed_outlined, Icons.bed_rounded, 'Rooms'),
        NavItem(Icons.calendar_today_outlined, Icons.calendar_month_rounded, 'Bookings', badge: s.upcoming.length),
        const NavItem(Icons.favorite_border_rounded, Icons.favorite_rounded, 'Saved'),
        const NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Account'),
      ],
      body: FadeIndexedStack(
        index: index,
        children: [for (var i = 0; i < tabs.length; i++) HeroMode(enabled: i == index, child: tabs[i])],
      ),
    );
  }
}
