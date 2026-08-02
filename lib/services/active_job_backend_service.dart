import 'package:supabase_flutter/supabase_flutter.dart';

class ActiveJobBackendService {
  ActiveJobBackendService._();
  static final ActiveJobBackendService instance = ActiveJobBackendService._();
  final _client = Supabase.instance.client;

  Future<bool> updateStatus(String id, String status) async {
    try {
      await _client.from('active_jobs').update({'status': status}).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }
}
