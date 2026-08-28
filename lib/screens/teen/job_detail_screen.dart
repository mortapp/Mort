import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/backend_job.dart';
import '../../models/backend_job_application.dart';
import '../../models/backend_safety_report.dart';
import '../../services/application_backend_service.dart';
import '../../services/safety_backend_service.dart';
import '../../theme/mort_theme.dart';

class JobDetailScreen extends StatefulWidget {
  final dynamic job; // BackendJob or MockJob

  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _applying = false;
  String? _applicationStatus;

  Future<void> _showReportDialog(BuildContext context) async {
    final controller = TextEditingController();
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: MortTheme.surface,
          title: const Text(
            'Report this job',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share what happened so MORT can review it. Keep details factual and concise.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Describe the issue...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: MortTheme.elevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MortTheme.primaryPurple,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit report'),
            ),
          ],
        );
      },
    );

    if (shouldSubmit != true) return;

    final details = controller.text.trim();
    if (details.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a short description.')),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to submit a report.')),
      );
      return;
    }

    final backendJob = widget.job is BackendJob
        ? widget.job as BackendJob
        : null;
    final jobId = backendJob?.id;
    final reportedUserId = backendJob?.posterId;

    final report = BackendSafetyReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      reporterId: user.id,
      reportedUserId: reportedUserId,
      jobId: jobId,
      reportType: 'job_report',
      severity: 'medium',
      status: 'open',
      details: details,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await SafetyBackendService.instance.submitReport(report);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Report submitted. MORT will review it shortly.'
              : 'Report could not be submitted right now.',
        ),
      ),
    );
  }

  Future<void> _handleAccept(BuildContext context) async {
    final backendJob = widget.job is BackendJob
        ? widget.job as BackendJob
        : null;
    if (backendJob == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This job is not available to apply to right now.'),
        ),
      );
      return;
    }

    setState(() {
      _applying = true;
      _applicationStatus = null;
    });

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _applying = false;
        _applicationStatus = 'You must be logged in to apply.';
      });
      return;
    }

    final app = BackendJobApplication(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      jobId: backendJob.id,
      teenId: user.id,
      applicationStatus: 'submitted',
      safetyAcknowledged: true,
      parentNoticeStatus: 'not_required',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await ApplicationBackendService.instance.applyToJob(app);

    if (!mounted) return;
    setState(() {
      _applying = false;
      _applicationStatus = success
          ? 'Application submitted! Check your messages for updates.'
          : 'Failed to submit application. Try again.';
    });

    if (success) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pop(backendJob);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBackendJob = widget.job is BackendJob;

    return Scaffold(
      backgroundColor: MortTheme.background,
      appBar: AppBar(
        title: const Text('Job Details'),
        backgroundColor: MortTheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (isBackendJob)
              Text(
                (widget.job as BackendJob).title ?? 'Untitled job',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Text(
                'Job unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            if (isBackendJob)
              Text(
                (widget.job as BackendJob).category ?? 'General',
                style: const TextStyle(color: Colors.white70),
              )
            else
              const Text(
                'This job is no longer available.',
                style: TextStyle(color: Colors.white70),
              ),
            const SizedBox(height: 16),
            if (isBackendJob)
              Row(
                children: [
                  _detailBadge(
                    '\$${((widget.job as BackendJob).teenPayoutCents ?? 0) ~/ 100}',
                  ),
                  const SizedBox(width: 10),
                  if ((widget.job as BackendJob).areaLabel != null)
                    _detailBadge((widget.job as BackendJob).areaLabel!),
                  const SizedBox(width: 10),
                  _detailBadge(
                    '${(widget.job as BackendJob).estimatedMinutes} min',
                  ),
                ],
              ),
            const SizedBox(height: 20),
            _sectionTitle('Description'),
            if (isBackendJob)
              Text(
                (widget.job as BackendJob).description ?? 'No description',
                style: const TextStyle(color: Colors.white70),
              )
            else
              const Text(
                'No details available for this job.',
                style: TextStyle(color: Colors.white70),
              ),
            const SizedBox(height: 16),
            if (isBackendJob &&
                (widget.job as BackendJob).safetyNotes != null) ...[
              _sectionTitle('Safety Notes'),
              Text(
                (widget.job as BackendJob).safetyNotes!,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 16),
            const SizedBox(height: 24),
            if (_applicationStatus != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _applicationStatus!.contains('submitted')
                      ? Colors.green.shade900
                      : Colors.red.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _applicationStatus!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: _applying ? null : () => _handleAccept(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: MortTheme.primaryPurple,
              ),
              child: Text(_applying ? 'Applying…' : 'Accept Job'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _showReportDialog(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: MortTheme.primaryPurple),
              ),
              child: const Text('Report Job'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailBadge(String label) {
    return Container(
      decoration: BoxDecoration(
        color: MortTheme.elevated,
        borderRadius: BorderRadius.circular(14.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(label, style: const TextStyle(color: Colors.white70)),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
