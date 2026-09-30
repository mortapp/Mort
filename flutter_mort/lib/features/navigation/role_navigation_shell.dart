import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/mort_widgets.dart';

enum MortRoleTabs { adult, guardian }

/// Main role navigation. Route guards and sensitive-screen wrappers remain in
/// the router; this shell only preserves tab state and system Back behavior.
class MortRoleShell extends StatefulWidget {
  const MortRoleShell({
    super.key,
    required this.navigationShell,
    required this.tabs,
  });

  final StatefulNavigationShell navigationShell;
  final MortRoleTabs tabs;

  @override
  State<MortRoleShell> createState() => _MortRoleShellState();
}

class _MortRoleShellState extends State<MortRoleShell> {
  final List<int> _history = [];

  @override
  void initState() {
    super.initState();
    if (widget.navigationShell.currentIndex != 0) _history.add(0);
  }

  void _select(int index) {
    final current = widget.navigationShell.currentIndex;
    if (index == current) {
      widget.navigationShell.goBranch(index, initialLocation: true);
      return;
    }
    setState(() {
      _history.remove(index);
      _history.add(current);
    });
    widget.navigationShell.goBranch(index);
  }

  void _back() {
    if (_history.isEmpty) return;
    final index = _history.removeLast();
    setState(() {});
    widget.navigationShell.goBranch(index);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: _history.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: widget.navigationShell,
        bottomNavigationBar: keyboardVisible
            ? null
            : MortBottomNavigation(
                index: widget.navigationShell.currentIndex,
                destinations: widget.tabs == MortRoleTabs.adult
                    ? _adultDestinations
                    : _guardianDestinations,
                onDestinationSelected: _select,
              ),
      ),
    );
  }
}

const _adultDestinations = [
  NavigationDestination(
    label: 'Home',
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home_rounded),
  ),
  NavigationDestination(
    label: 'Jobs',
    icon: Icon(Icons.work_outline_rounded),
    selectedIcon: Icon(Icons.work_rounded),
  ),
  NavigationDestination(
    label: 'Messages',
    icon: Icon(Icons.chat_bubble_outline_rounded),
    selectedIcon: Icon(Icons.chat_bubble_rounded),
  ),
  NavigationDestination(
    label: 'Safety',
    icon: Icon(Icons.shield_outlined),
    selectedIcon: Icon(Icons.shield_rounded),
  ),
  NavigationDestination(
    label: 'Profile',
    icon: Icon(Icons.person_outline_rounded),
    selectedIcon: Icon(Icons.person_rounded),
  ),
];

const _guardianDestinations = [
  NavigationDestination(
    label: 'Home',
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home_rounded),
  ),
  NavigationDestination(
    label: 'Safety',
    icon: Icon(Icons.shield_outlined),
    selectedIcon: Icon(Icons.shield_rounded),
  ),
  NavigationDestination(
    label: 'Messages',
    icon: Icon(Icons.chat_bubble_outline_rounded),
    selectedIcon: Icon(Icons.chat_bubble_rounded),
  ),
  NavigationDestination(
    label: 'Profile',
    icon: Icon(Icons.person_outline_rounded),
    selectedIcon: Icon(Icons.person_rounded),
  ),
];
