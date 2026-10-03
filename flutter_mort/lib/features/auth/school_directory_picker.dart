import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/school_directory_entry.dart';
import '../../data/repositories/providers.dart';
import 'school_directory_request_screen.dart';

/// A full-screen, server-backed selector. Listing a school does not imply
/// that MORT has approved its student email domain.
class SchoolDirectoryPicker extends ConsumerStatefulWidget {
  const SchoolDirectoryPicker({super.key});

  @override
  ConsumerState<SchoolDirectoryPicker> createState() =>
      _SchoolDirectoryPickerState();
}

class _SchoolDirectoryPickerState extends ConsumerState<SchoolDirectoryPicker> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  int _requestSerial = 0;
  List<SchoolDirectoryEntry> _schools = const [];
  SchoolDirectoryEntry? _selected;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => _search(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    // A choice from a previous result set must not survive a new search.
    if (_selected != null) setState(() => _selected = null);
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(value));
  }

  Future<void> _search(String query) async {
    final serial = ++_requestSerial;
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final schools = await ref
          .read(schoolDirectoryRepositoryProvider)
          .search(query);
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _schools = schools;
        if (_selected != null &&
            !schools.any((school) => school.id == _selected!.id)) {
          _selected = null;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _schools = const [];
        _loading = false;
        _error = 'Schools could not be loaded. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      scroll: false,
      padding: const EdgeInsets.fromLTRB(
        MortSpacing.md,
        MortSpacing.md,
        MortSpacing.md,
        0,
      ),
      bottom: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          MortSpacing.md,
          MortSpacing.sm,
          MortSpacing.md,
          MortSpacing.md,
        ),
        child: FilledButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: const Text('Continue'),
        ),
      ),
      children: [
        const MortHeader(
          title: 'Find your school',
          subtitle: 'Choose the school that issued your email.',
          showBackButton: true,
        ),
        TextField(
          controller: _searchController,
          onChanged: _onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Search schools',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: MortSpacing.sm),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: () => _search(_searchController.text),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _schools.isEmpty
              ? const Center(child: Text('No matching schools found.'))
              : ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: _schools.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final school = _schools[index];
                    final selected = _selected?.id == school.id;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: MortSpacing.xs,
                      ),
                      selected: selected,
                      selectedTileColor: MortClassicColors.surface,
                      title: Text(school.displayName),
                      subtitle: Text(
                        '${school.city}, ${school.state} · ${school.typeLabel}',
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: MortClassicColors.ink,
                            )
                          : null,
                      onTap: () => setState(() => _selected = school),
                    );
                  },
                ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => SchoolDirectoryRequestScreen(
                initialSchoolName: _searchController.text.trim(),
              ),
            ),
          ),
          child: const Text("Can't find your school? Request your school"),
        ),
      ],
    );
  }
}
