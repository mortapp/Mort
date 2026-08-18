import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mort_colors.dart';
import '../../core/widgets/mort_liquid_glass.dart';

class TeenShell extends StatefulWidget {
  const TeenShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<TeenShell> createState() => _TeenShellState();
}

class _TeenShellState extends State<TeenShell> {
  final List<int> _destinationHistory = [];

  @override
  void initState() {
    super.initState();
    if (widget.navigationShell.currentIndex != 0) {
      _destinationHistory.add(0);
    }
  }

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
    return TeenNavigationScope(
      canGoBack: _canReturnToPreviousDestination,
      onBack: _returnToPreviousDestination,
      child: PopScope(
        canPop: !_canReturnToPreviousDestination,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _returnToPreviousDestination();
        },
        child: Scaffold(
          backgroundColor: MortColors.bg,
          body: widget.navigationShell,
          bottomNavigationBar: keyboardVisible
              ? null
              : MortGlassNavigationBar(
                  currentIndex: widget.navigationShell.currentIndex,
                  destinations: _teenDestinations,
                  onDestinationSelected: _selectDestination,
                ),
        ),
      ),
    );
  }
}

class TeenNavigationScope extends InheritedWidget {
  const TeenNavigationScope({
    super.key,
    required this.canGoBack,
    required this.onBack,
    required super.child,
  });

  final bool canGoBack;
  final VoidCallback onBack;

  static TeenNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TeenNavigationScope>();

  @override
  bool updateShouldNotify(TeenNavigationScope oldWidget) =>
      canGoBack != oldWidget.canGoBack || onBack != oldWidget.onBack;
}

class MortTeenDestinationHeader extends StatelessWidget {
  const MortTeenDestinationHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final navigation = TeenNavigationScope.maybeOf(context);
    return MortGlassHeader(
      title: title,
      eyebrow: eyebrow,
      subtitle: subtitle,
      trailing: trailing,
      showBack: navigation?.canGoBack == true,
      onBack: navigation?.onBack,
    );
  }
}

const _teenDestinations = [
  MortNavigationDestination(
    label: 'Dashboard',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
  ),
  MortNavigationDestination(
    label: 'Jobs',
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment_rounded,
  ),
  MortNavigationDestination(
    label: 'Safety',
    icon: Icons.shield_outlined,
    selectedIcon: Icons.shield_rounded,
  ),
  MortNavigationDestination(
    label: 'Messages',
    icon: Icons.chat_bubble_outline_rounded,
    selectedIcon: Icons.chat_bubble_rounded,
  ),
  MortNavigationDestination(
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];
