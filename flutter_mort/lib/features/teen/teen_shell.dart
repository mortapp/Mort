import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/mort_widgets.dart';

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
    return ShellBackNavigationScope(
      canGoBack: _canReturnToPreviousDestination,
      onBack: _returnToPreviousDestination,
      child: TeenNavigationScope(
        canGoBack: _canReturnToPreviousDestination,
        onBack: _returnToPreviousDestination,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
    return MortHeader(
      title: title,
      eyebrow: eyebrow,
      subtitle: subtitle,
      trailing: trailing,
      showBackButton: false,
      leading: navigation?.canGoBack == true
          ? Semantics(
              button: true,
              label: 'Back',
              child: IconButton(
                tooltip: 'Back',
                onPressed: navigation?.onBack,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            )
          : null,
    );
  }
}

const _teenDestinations = [
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
