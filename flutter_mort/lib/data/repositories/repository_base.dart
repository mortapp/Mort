import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

abstract class RepositoryBase {
  SupabaseClient get client => SupabaseService.client;

  String requireUserId() {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('A signed-in Supabase user is required.');
    return id;
  }
}
