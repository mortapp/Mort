import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mort_mascots.dart';

/// Persists the teen's chosen MORT Guide mascot.
///
/// This preference only changes the Guide's companion UI. It never touches
/// sign-in, identity storage, roles, or permissions: changing a mascot
/// writes exactly one SharedPreferences key and nothing else. Reading an
/// unknown stored value fails closed to null (first-open introduction).
class MortMascotPreferenceController extends AsyncNotifier<MortMascotId?> {
  static const storageKey = 'mort.preference.guide_mascot';

  @override
  Future<MortMascotId?> build() async {
    final preferences = await SharedPreferences.getInstance();
    return MortMascotId.tryParse(preferences.getString(storageKey));
  }

  Future<void> choose(MortMascotId mascot) async {
    state = AsyncData(mascot);
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(storageKey, mascot.name);
    if (!saved) {
      state = const AsyncData(null);
      throw StateError('Mascot preference was not saved.');
    }
  }
}

final mascotPreferenceProvider =
    AsyncNotifierProvider<MortMascotPreferenceController, MortMascotId?>(
      MortMascotPreferenceController.new,
    );
