import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';

class SafetyHomeCard extends ConsumerStatefulWidget {
  const SafetyHomeCard({super.key, this.guardian = false});
  final bool guardian;
  @override
  ConsumerState<SafetyHomeCard> createState() => _SafetyHomeCardState();
}

class _SafetyHomeCardState extends ConsumerState<SafetyHomeCard> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final result = _loadChecked();
    result.ignore();
    return result;
  }

  Future<Map<String, dynamic>> _loadChecked() async {
    final repo = ref.read(safetyRepositoryProvider);
    final events = await repo.listSafetyEvents();
    final teens = widget.guardian
        ? await repo.listGuardianStatus()
        : <Map<String, dynamic>>[];
    return {'events': events, 'teens': teens};
  }

  @override
  Widget build(BuildContext context) => MortCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MortSectionTitle(title: 'Safety Updates'),
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Text(
                'Safety status is unavailable. Refresh when connected.',
              );
            if (snapshot.connectionState != ConnectionState.done ||
                !snapshot.hasData)
              return const Text('Checking authorized Safety updates…');
            final events =
                snapshot.data!['events'] as List<Map<String, dynamic>>;
            final teens = snapshot.data!['teens'] as List<Map<String, dynamic>>;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (events.isEmpty)
                  const Text('No active Safety event is shared with you.'),
                for (final teen in teens) ...[
                  Text(
                    teen['teen_name']?.toString() ?? 'Linked teen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    teen['job_title']?.toString() ?? 'No job summary shared',
                  ),
                  if (teen['safety_state'] != null)
                    Text('Safety: ${teen['safety_state']}'),
                  if (teen['travel_state'] != null)
                    Text(
                      'Travel: ${teen['travel_state']}. Exact location sharing is off unless explicitly enabled.',
                    ),
                  if (teen['last_checkin_at'] != null)
                    Text('Last check-in: ${teen['last_checkin_at']}'),
                  if (teen['eta_range_min'] != null &&
                      teen['eta_range_max'] != null)
                    Text(
                      'Estimated arrival: ${teen['eta_range_min']}–${teen['eta_range_max']} minutes',
                    ),
                  if (teen['connection_lost'] == true)
                    const Text(
                      'Connection lost. This does not necessarily mean danger.',
                    ),
                ],
                for (final event in events)
                  TextButton(
                    onPressed: () =>
                        context.push('/safety/events/${event['event_id']}'),
                    child: Text(
                      'Open Safety event — ${event['teen_name'] ?? 'linked teen'}',
                    ),
                  ),
              ],
            );
          },
        ),
        TextButton(
          onPressed: () => setState(() {
            _future = _load();
          }),
          child: const Text('Refresh Safety updates'),
        ),
      ],
    ),
  );
}
