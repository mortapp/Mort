import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/providers.dart';

class ProfileAvatarView extends ConsumerStatefulWidget {
  const ProfileAvatarView({
    super.key,
    required this.profileId,
    required this.avatarPath,
    required this.fallbackLabel,
    this.avatarUpdatedAt,
    this.radius = 30,
  });

  final String profileId;
  final String? avatarPath;
  final String fallbackLabel;
  final DateTime? avatarUpdatedAt;
  final double radius;

  @override
  ConsumerState<ProfileAvatarView> createState() => _ProfileAvatarViewState();

  static String initials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final initials = words.take(2).map((word) => word[0].toUpperCase()).join();
    return initials.isEmpty ? 'M' : initials;
  }
}

class _ProfileAvatarViewState extends ConsumerState<ProfileAvatarView> {
  late Future<String?> _signedUrl;
  int _retry = 0;

  @override
  void initState() {
    super.initState();
    _signedUrl = _load();
  }

  @override
  void didUpdateWidget(covariant ProfileAvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId ||
        oldWidget.avatarPath != widget.avatarPath ||
        oldWidget.avatarUpdatedAt != widget.avatarUpdatedAt) {
      _retry = 0;
      _signedUrl = _load();
    }
  }

  Future<String?> _load({bool forceRefresh = false}) => ref
      .read(avatarRepositoryProvider)
      .signedAvatarUrl(
        profileId: widget.profileId,
        avatarPath: widget.avatarPath,
        avatarUpdatedAt: widget.avatarUpdatedAt,
        forceRefresh: forceRefresh,
      );

  void _retryLoad() {
    setState(() {
      _retry += 1;
      _signedUrl = _load(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.avatarPath == null) {
      return MortAvatar(
        label: ProfileAvatarView.initials(widget.fallbackLabel),
        radius: widget.radius,
      );
    }
    return FutureBuilder<String?>(
      key: ValueKey(
        '${widget.profileId}|${widget.avatarPath}|${widget.avatarUpdatedAt?.toIso8601String()}|$_retry',
      ),
      future: _signedUrl,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox.square(
            dimension: widget.radius * 2,
            child: const Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        if (snapshot.hasError) {
          return _AvatarRetry(radius: widget.radius, onRetry: _retryLoad);
        }
        final url = snapshot.data;
        if (url == null) {
          return MortAvatar(
            label: ProfileAvatarView.initials(widget.fallbackLabel),
            radius: widget.radius,
          );
        }
        return Semantics(
          image: true,
          label: '${widget.fallbackLabel} profile picture',
          child: ClipOval(
            child: SizedBox.square(
              dimension: widget.radius * 2,
              child: Image.network(
                url,
                key: ValueKey(url),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _AvatarRetry(radius: widget.radius, onRetry: _retryLoad),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AvatarRetry extends StatelessWidget {
  const _AvatarRetry({required this.radius, required this.onRetry});

  final double radius;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Profile picture could not load. Retry.',
    child: SizedBox.square(
      dimension: radius * 2,
      child: Material(
        color: MortColors.cardAlt,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: 'Retry profile picture',
          icon: const Icon(Icons.refresh),
          onPressed: onRetry,
        ),
      ),
    ),
  );
}

class ProfileAvatarEditor extends ConsumerStatefulWidget {
  const ProfileAvatarEditor({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<ProfileAvatarEditor> createState() =>
      _ProfileAvatarEditorState();
}

class _ProfileAvatarEditorState extends ConsumerState<ProfileAvatarEditor> {
  bool _busy = false;

  Future<void> _choose(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repository = ref.read(avatarRepositoryProvider);
      final file = await repository.choosePhoto(source: source);
      if (file == null) return;
      await repository.uploadAvatar(
        file,
        previousPath: widget.profile.avatarPath,
      );
      ref.invalidate(currentProfileProvider);
      await ref.read(currentProfileProvider.future);
      if (mounted) MortToast.show(context, 'Profile picture updated.');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    if (_busy || widget.profile.avatarPath == null) return;
    final confirmed = await MortConfirmSheet.show(
      context,
      title: 'Remove profile picture?',
      message: 'Your initials avatar will be restored.',
      confirmLabel: 'Remove photo',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(avatarRepositoryProvider)
          .removeAvatar(widget.profile.avatarPath);
      ref.invalidate(currentProfileProvider);
      await ref.read(currentProfileProvider.future);
      if (mounted) MortToast.show(context, 'Profile picture removed.');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        children: [
          ProfileAvatarView(
            profileId: widget.profile.id,
            avatarPath: widget.profile.avatarPath,
            avatarUpdatedAt: widget.profile.avatarUpdatedAt,
            fallbackLabel: widget.profile.displayName ?? 'MORT',
            radius: 42,
          ),
          const SizedBox(height: MortSpacing.sm),
          Text(
            'Profile picture',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: MortSpacing.xs),
          Text(
            'Photos are cropped square, resized, and re-encoded before private upload. Facial recognition is not used.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: MortSpacing.md),
          MortActionRow(
            actions: [
              MortAction(
                label: 'Choose photo',
                icon: Icons.photo_library_outlined,
                busy: _busy,
                onPressed: () => _choose(ImageSource.gallery),
              ),
              MortAction(
                label: 'Take photo',
                icon: Icons.photo_camera_outlined,
                busy: _busy,
                onPressed: () => _choose(ImageSource.camera),
              ),
              MortAction(
                label: 'Remove',
                icon: Icons.delete_outline,
                enabled: widget.profile.avatarPath != null,
                onPressed: _remove,
                style: MortButtonStyle.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
