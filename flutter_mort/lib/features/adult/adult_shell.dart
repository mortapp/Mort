import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/mort_widgets.dart';

class AdultShell extends StatefulWidget {
  const AdultShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AdultShell> createState() => _AdultShellState();
}

class _AdultShellState extends State<AdultShell> {
  final List<int> _destinationHistory = [];

  bool get _canReturnToPreviousDestination => _destinationHistory.isNotEmpty;

  void _selectDestination(int index) {
    final current = widget.navigationShell.currentIndex;
    if (index == current) {
      widget.navigationShell.goBranch(index, initialLocation: true);
      return;
    }
    setState(() {
      _destinationHistory.remove(index);
      _destinationHistory.add(current);
    });
    widget.navigationShell.goBranch(index);
  }

  void _returnToPreviousDestination() {
    if (_destinationHistory.isEmpty) return;
    final index = _destinationHistory.removeLast();
    setState(() {});
    widget.navigationShell.goBranch(index);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return ShellBackNavigationScope(
      canGoBack: _canReturnToPreviousDestination,
      onBack: _returnToPreviousDestination,
      child: AdultNavigationScope(
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: widget.navigationShell,
          bottomNavigationBar: keyboardVisible
              ? null
              : MortGlassNavigationBar(
                  currentIndex: widget.navigationShell.currentIndex,
                  destinations: _adultDestinations,
                  onDestinationSelected: _selectDestination,
                ),
        ),
      ),
    );
  }
}

class AdultNavigationScope extends InheritedWidget {
  const AdultNavigationScope({super.key, required super.child});

  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdultNavigationScope>() !=
      null;

  @override
  bool updateShouldNotify(AdultNavigationScope oldWidget) => false;
}

const _adultDestinations = [
  MortNavigationDestination(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  MortNavigationDestination(
    label: 'Explore',
    icon: Icons.search_rounded,
    selectedIcon: Icons.search_rounded,
  ),
  MortNavigationDestination(
    label: '+',
    icon: Icons.add_rounded,
    selectedIcon: Icons.add_rounded,
    accessibilityLabel: 'Post a job',
    prominentAction: true,
  ),
  MortNavigationDestination(
    label: 'Inbox',
    icon: Icons.chat_bubble_outline_rounded,
    selectedIcon: Icons.chat_bubble_rounded,
  ),
  MortNavigationDestination(
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];
