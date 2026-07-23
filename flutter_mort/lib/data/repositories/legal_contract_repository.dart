import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'repository_base.dart';

class LegalContractRepository extends RepositoryBase {
  Future<Map<String, dynamic>> legalRequirements() async {
    requireUserId();
    return _map(await client.rpc('get_my_legal_requirements'));
  }

  Future<Map<String, dynamic>> publishedLegalVersion(String versionId) async {
    requireUserId();
    return _map(
      await client
          .from('legal_document_versions')
          .select(
            'id,document_id,version_label,content_hash,content_markdown,effective_at,publication_status',
          )
          .eq('id', versionId)
          .eq('publication_status', 'published')
          .single(),
    );
  }

  Future<Map<String, dynamic>> acceptLegalVersion({
    required String versionId,
    required bool teenSummaryViewed,
    String? signature,
  }) async {
    requireUserId();
    final result = _map(
      await client.rpc(
        'submit_legal_acceptance',
        params: {
          'p_document_version_id': versionId,
          'p_affirmative_checkbox': true,
          'p_teen_summary_viewed': teenSummaryViewed,
          'p_electronic_signature_text': _blankToNull(signature),
          'p_platform': kIsWeb ? 'flutter_web' : 'flutter_native',
          'p_app_version': await _appVersion(),
          'p_language_code': 'en-US',
        },
      ),
    );
    return _requireOk(result, 'Legal acceptance could not be recorded.');
  }

  Future<List<Map<String, dynamic>>> contracts() async {
    requireUserId();
    return _rows(
      await client
          .from('job_contracts')
          .select(
            'id,job_id,application_id,teen_id,adult_id,status,active_version_id,classification_status,created_at,jobs:job_id(title)',
          )
          .order('created_at', ascending: false),
    );
  }

  Future<List<Map<String, dynamic>>> contractVersions(String contractId) async {
    requireUserId();
    return _rows(
      await client
          .from('job_contract_versions')
          .select()
          .eq('contract_id', contractId)
          .order('version_number', ascending: false),
    );
  }

  Future<List<Map<String, dynamic>>> contractAcceptances(
    String contractId,
  ) async {
    requireUserId();
    return _rows(
      await client
          .from('job_contract_acceptances')
          .select(
            'id,contract_version_id,user_id,party_role,content_hash,accepted_at',
          )
          .eq('contract_id', contractId)
          .order('accepted_at'),
    );
  }

  Future<Map<String, dynamic>> confirmContractVersion({
    required String versionId,
    required String confirmation,
  }) async {
    requireUserId();
    return _requireOk(
      _map(
        await client.rpc(
          'confirm_job_contract_version',
          params: {
            'p_contract_version_id': versionId,
            'p_affirmative_checkbox': true,
            'p_confirmation_text': confirmation.trim(),
            'p_platform': kIsWeb ? 'flutter_web' : 'flutter_native',
            'p_app_version': await _appVersion(),
          },
        ),
      ),
      'The exact agreement version could not be confirmed.',
    );
  }

  Future<List<Map<String, dynamic>>> contractChanges(String contractId) async {
    requireUserId();
    return _rows(
      await client
          .from('job_contract_change_requests')
          .select(
            'id,contract_id,requested_by,change_categories,proposed_terms,proposed_content_hash,reason,status,requested_at',
          )
          .eq('contract_id', contractId)
          .order('requested_at', ascending: false),
    );
  }

  Future<Map<String, dynamic>> requestContractChange({
    required String contractId,
    required Map<String, dynamic> patch,
    required String reason,
  }) async {
    requireUserId();
    return _requireOk(
      _map(
        await client.rpc(
          'request_job_contract_change',
          params: {
            'p_contract_id': contractId,
            'p_patch': patch,
            'p_reason': reason.trim(),
          },
        ),
      ),
      'The material-change proposal could not be created.',
    );
  }

  Future<Map<String, dynamic>> respondContractChange({
    required String changeId,
    required bool accept,
  }) async {
    requireUserId();
    return _requireOk(
      _map(
        await client.rpc(
          'respond_job_contract_change',
          params: {
            'p_change_request_id': changeId,
            'p_accept': accept,
            'p_affirmative_checkbox': accept,
          },
        ),
      ),
      'The material-change response could not be saved.',
    );
  }

  Future<List<Map<String, dynamic>>> paymentObligations(
    String contractId,
  ) async {
    requireUserId();
    return _rows(
      await client
          .from('job_payment_obligations')
          .select(
            'id,contract_id,amount_cents,currency_code,payment_preference,due_rule,due_at,status,became_due_at,satisfied_at,disputed_at',
          )
          .eq('contract_id', contractId)
          .order('created_at', ascending: false),
    );
  }

  Future<List<Map<String, dynamic>>> paymentDisputes(String contractId) async {
    requireUserId();
    return _rows(
      await client
          .from('payment_disputes')
          .select(_disputeFields)
          .eq('contract_id', contractId)
          .order('opened_at', ascending: false),
    );
  }

  Future<Map<String, dynamic>> paymentDispute(String disputeId) async {
    requireUserId();
    return _map(
      await client
          .from('payment_disputes')
          .select(_disputeFields)
          .eq('id', disputeId)
          .single(),
    );
  }

  Future<List<Map<String, dynamic>>> disputeTimeline(String disputeId) async {
    requireUserId();
    return _rows(
      await client
          .from('payment_dispute_timeline')
          .select('id,event_type,event_summary,created_at')
          .eq('dispute_id', disputeId)
          .order('created_at'),
    );
  }

  Future<Map<String, dynamic>> reportNonpayment({
    required String obligationId,
    required String statement,
  }) async {
    requireUserId();
    return _requireOk(
      _map(
        await client.rpc(
          'report_nonpayment',
          params: {
            'p_obligation_id': obligationId,
            'p_worker_statement': statement.trim(),
          },
        ),
      ),
      'The private nonpayment report could not be opened.',
    );
  }

  Future<Map<String, dynamic>> submitDisputeStatement({
    required String disputeId,
    required String statement,
  }) async {
    requireUserId();
    return _requireOk(
      _map(
        await client.rpc(
          'submit_payment_dispute_statement',
          params: {'p_dispute_id': disputeId, 'p_statement': statement.trim()},
        ),
      ),
      'The private dispute statement could not be saved.',
    );
  }

  Future<Map<String, dynamic>> evidenceExport(String disputeId) async {
    requireUserId();
    return _requireOk(
      _map(
        await client.rpc(
          'request_payment_evidence_export',
          params: {'p_dispute_id': disputeId},
        ),
      ),
      'The authorized evidence export could not be generated.',
    );
  }

  Future<Map<String, dynamic>> firstPartyTrustStatus() async {
    requireUserId();
    return _map(await client.rpc('get_first_party_trust_status'));
  }

  Map<String, dynamic> _requireOk(Map<String, dynamic> value, String fallback) {
    if (value['ok'] == true) return value;
    throw StateError(value['code']?.toString() ?? fallback);
  }

  Map<String, dynamic> _map(dynamic value) =>
      Map<String, dynamic>.from(value as Map);

  List<Map<String, dynamic>> _rows(dynamic value) => (value as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList(growable: false);

  String? _blankToNull(String? value) {
    final clean = value?.trim() ?? '';
    return clean.isEmpty ? null : clean;
  }

  Future<String> _appVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version.isEmpty ? 'unversioned' : info.version;
  }

  static const _disputeFields =
      'id,obligation_id,contract_id,status,guilt_determined,classification_status,worker_statement,poster_statement,retaliation_review_active,publication_paused,opened_at';
}
