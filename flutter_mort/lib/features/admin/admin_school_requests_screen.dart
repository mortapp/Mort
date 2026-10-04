import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';

/// Private triage only. Neither action lists a school or approves a domain.
class AdminSchoolRequestsScreen extends ConsumerStatefulWidget {
  const AdminSchoolRequestsScreen({super.key});

  @override
  ConsumerState<AdminSchoolRequestsScreen> createState() =>
      _AdminSchoolRequestsScreenState();
}

class _AdminSchoolRequestsScreenState
    extends ConsumerState<AdminSchoolRequestsScreen> {
  static const _pageSize = 25;
  String _status = 'pending';
  String? _busyId;
  bool _hasMore = true;
  int _generation = 0;
  late Future<List<Map<String, dynamic>>> _requests;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final generation = ++_generation;
    _hasMore = true;
    _requests = ref
        .read(adminRepositoryProvider)
        .schoolDirectoryRequests(status: _status, limit: _pageSize)
        .then((page) {
          if (generation == _generation) _hasMore = page.length == _pageSize;
          return page;
        });
  }

  void _refresh() => setState(_reload);

  void _loadMore() {
    final generation = _generation;
    final previous = _requests;
    final repository = ref.read(adminRepositoryProvider);
    final status = _status;
    setState(() {
      _requests = () async {
        final existing = await previous;
        final page = await repository.schoolDirectoryRequests(
          status: status,
          limit: _pageSize,
          offset: existing.length,
        );
        if (generation == _generation) _hasMore = page.length == _pageSize;
        return [...existing, ...page];
      }();
    });
  }

  Future<String?> _reviewNote(String action) async {
    var draft = '';
    String? validation;
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('$action school request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Record the source and reason. This action does not approve a school or student email domain.',
                ),
                const SizedBox(height: MortSpacing.sm),
                TextField(
                  onChanged: (value) => draft = value,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    labelText: 'Review note',
                    errorText: validation,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = draft.trim();
                if (value.length < 10) {
                  setDialogState(
                    () => validation = 'Enter at least 10 characters.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Record decision'),
            ),
          ],
        ),
      ),
    );
    return note;
  }

  Future<void> _triage(String id, String decision) async {
    if (_busyId != null) return;
    final note = await _reviewNote(
      decision == 'reviewing' ? 'Start review for' : 'Reject',
    );
    if (note == null || !mounted) return;
    setState(() => _busyId = id);
    try {
      await ref
          .read(adminRepositoryProvider)
          .triageSchoolDirectoryRequest(
            requestId: id,
            decision: decision,
            note: note,
          );
      if (!mounted) return;
      MortToast.show(context, 'The review decision was recorded.');
      _refresh();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Restricted operations',
          title: 'School requests',
          subtitle:
              'Unverified suggestions. Review and rejection are recorded; student email eligibility stays closed.',
          trailing: MortIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh school requests',
            onPressed: _busyId == null ? _refresh : null,
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Review status'),
          items: const [
            DropdownMenuItem(value: 'pending', child: Text('Pending')),
            DropdownMenuItem(value: 'reviewing', child: Text('Reviewing')),
            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
            DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
          ],
          onChanged: _busyId == null
              ? (value) {
                  if (value == null) return;
                  setState(() {
                    _status = value;
                    _reload();
                  });
                }
              : null,
        ),
        const SizedBox(height: MortSpacing.md),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'School requests unavailable',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _refresh,
                ),
              );
            }
            final requests = snapshot.data ?? const [];
            if (requests.isEmpty) {
              return const MortEmptyState(
                title: 'No requests in this queue',
                message: 'Refresh after new school suggestions arrive.',
              );
            }
            return Column(
              children: [
                for (final request in requests) ...[
                  MortCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request['requested_school_name']?.toString() ??
                              'Unnamed school',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${request['requested_city'] ?? ''}, ${request['requested_state'] ?? ''}',
                        ),
                        if (request['school_website'] != null)
                          SelectableText(
                            'Suggested website: ${request['school_website']}',
                          ),
                        if (request['suggested_student_domain'] != null)
                          SelectableText(
                            'Suggested domain: ${request['suggested_student_domain']}',
                          ),
                        if (request['review_notes'] != null)
                          Text('Review note: ${request['review_notes']}'),
                        if (_status == 'pending' || _status == 'reviewing') ...[
                          const SizedBox(height: MortSpacing.sm),
                          MortActionRow(
                            actions: [
                              if (_status == 'pending')
                                MortAction(
                                  label: 'Start review',
                                  icon: Icons.fact_check_outlined,
                                  busy: _busyId == request['id']?.toString(),
                                  onPressed: () => _triage(
                                    request['id'].toString(),
                                    'reviewing',
                                  ),
                                ),
                              MortAction(
                                label: 'Reject',
                                icon: Icons.block_outlined,
                                busy: _busyId == request['id']?.toString(),
                                onPressed: () => _triage(
                                  request['id'].toString(),
                                  'rejected',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
                if (_hasMore)
                  MortButton(
                    label: 'Load more requests',
                    icon: Icons.expand_more,
                    onPressed: _loadMore,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
