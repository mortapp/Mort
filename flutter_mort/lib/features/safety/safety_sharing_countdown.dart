import 'dart:async';
import 'package:flutter/material.dart';

/// Local expiration changes the label even when the next network read fails.
/// This narrow timer never sends a request or starts location sharing.
class SafetySharingCountdown extends StatefulWidget {
  const SafetySharingCountdown({super.key, required this.expiresAt, this.now});
  final DateTime? expiresAt;
  final DateTime Function()? now;
  @override
  State<SafetySharingCountdown> createState() => _SafetySharingCountdownState();
}

class _SafetySharingCountdownState extends State<SafetySharingCountdown> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant SafetySharingCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) _startTimer();
  }

  int get _seconds =>
      widget.expiresAt?.difference((widget.now ?? DateTime.now)()).inSeconds ??
      0;
  void _startTimer() {
    _timer?.cancel();
    if (_seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_seconds <= 0) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _seconds;
    return Text(
      seconds <= 0
          ? 'Live sharing: Off'
          : 'Live sharing: ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} remaining',
    );
  }
}
