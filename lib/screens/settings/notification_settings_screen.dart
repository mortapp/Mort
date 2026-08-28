import 'package:flutter/material.dart';
import '../../theme/mort_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool jobAlerts = true;
  bool safetyAlerts = true;
  bool accountAlerts = true;
  bool parentAlerts = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MortTheme.background,
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: MortTheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              SwitchListTile(
                title: const Text(
                  'Job alerts',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Mock updates about jobs and applications.',
                  style: TextStyle(color: Colors.white70),
                ),
                value: jobAlerts,
                activeThumbColor: MortTheme.primaryPurple,
                onChanged: (value) => setState(() => jobAlerts = value),
              ),
              SwitchListTile(
                title: const Text(
                  'Safety alerts',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Mock safety reminders and check-in prompts.',
                  style: TextStyle(color: Colors.white70),
                ),
                value: safetyAlerts,
                activeThumbColor: MortTheme.primaryPurple,
                onChanged: (value) => setState(() => safetyAlerts = value),
              ),
              SwitchListTile(
                title: const Text(
                  'Account alerts',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Mock account and profile updates.',
                  style: TextStyle(color: Colors.white70),
                ),
                value: accountAlerts,
                activeThumbColor: MortTheme.primaryPurple,
                onChanged: (value) => setState(() => accountAlerts = value),
              ),
              SwitchListTile(
                title: const Text(
                  'Parent alerts',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Mock alerts for parent-linked activity.',
                  style: TextStyle(color: Colors.white70),
                ),
                value: parentAlerts,
                activeThumbColor: MortTheme.primaryPurple,
                onChanged: (value) => setState(() => parentAlerts = value),
              ),
              const SizedBox(height: 20),
              const Text(
                'Notifications are mock-only in this prototype.',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
