import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../core/theme/mort_spacing.dart';
import '../../data/repositories/providers.dart';

class SafetyContactScreen extends ConsumerStatefulWidget {
  const SafetyContactScreen({super.key, required this.threadId});
  final String threadId;
  @override
  ConsumerState<SafetyContactScreen> createState() =>
      _SafetyContactScreenState();
}

class _SafetyContactScreenState extends ConsumerState<SafetyContactScreen> {
  final _body = TextEditingController();
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;
  String? _request;
  String? _requestBody;
  Timer? _poll;
  @override
  void initState() {
    super.initState();
    _future = _load();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (mounted &&
          !_busy &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
        setState(() {
          _future = _load();
        });
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _body.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() {
    final result = ref
        .read(safetyRepositoryProvider)
        .getSafetyContact(widget.threadId)
        .timeout(const Duration(seconds: 8));
    result.ignore();
    return result;
  }

  Future<void> _send([String? preset]) async {
    final body = (preset ?? _body.text).trim();
    if (_busy || body.isEmpty) return;
    if (_requestBody != body) {
      _request = const Uuid().v4();
      _requestBody = body;
    }
    setState(() => _busy = true);
    try {
      final message = await ref
          .read(messagingRepositoryProvider)
          .sendSafeMessage(widget.threadId, body, clientRequestId: _request)
          .timeout(const Duration(seconds: 8));
      _request = null;
      _requestBody = null;
      if (mounted) {
        _body.clear();
        setState(() {
          _future = _load();
        });
        MortToast.show(
          context,
          message.blocked
              ? 'The message was blocked by safety controls.'
              : 'Message recorded. Device delivery is not confirmed.',
        );
      }
    } catch (_) {
      if (mounted)
        MortToast.show(
          context,
          'Message not confirmed. The contact may have ended or MORT may be offline.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MortScreen(
    atmosphereIntensity: MortAtmosphereIntensity.midnight,
    children: [
      const MortHeader(
        eyebrow: 'Temporary event contact',
        title: 'Safety Contact',
        subtitle:
            'This conversation is separate from the private job chat. Reports and location are not shared here.',
      ),
      const MortSafetyBanner(
        message:
            'Poster responses are statements to review. They do not close the safety event, mark the teen safe, or confirm job completion.',
      ),
      const SizedBox(height: MortSpacing.md),
      FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const MortErrorState(
              title: 'Safety Contact unavailable',
              message:
                  'Event access may have ended or the safety relationship may have changed.',
            );
          if (snapshot.connectionState != ConnectionState.done ||
              !snapshot.hasData)
            return const MortLoading(
              label: 'Loading event contact...',
              fullScreen: false,
            );
          final messages = (snapshot.data!['messages'] as List? ?? []).reversed;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final message in messages) ...[
                MortCard(
                  child: Text(
                    message['body']?.toString() ?? 'Message unavailable',
                  ),
                ),
                const SizedBox(height: MortSpacing.sm),
              ],
              MortTextArea(
                label: 'Safety message',
                controller: _body,
                maxLength: 2000,
                maxLines: 3,
              ),
              MortButton(
                label: 'Send Safety Message',
                busy: _busy,
                onPressed: _busy ? null : () => _send(),
              ),
              if (snapshot.data!['kind'] == 'poster' &&
                  snapshot.data!['is_poster'] == true) ...[
                const MortSectionTitle(title: 'Share a status statement'),
                for (final statement in [
                  'The worker is here with me',
                  'The worker left the job',
                  'I have not seen the worker yet',
                  'The job ended',
                  'I need help too',
                ])
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _send('Safety Contact statement: $statement.'),
                    child: Text(statement),
                  ),
              ],
            ],
          );
        },
      ),
      TextButton(
        onPressed: () => setState(() {
          _future = _load();
        }),
        child: const Text('Refresh messages'),
      ),
    ],
  );
}
