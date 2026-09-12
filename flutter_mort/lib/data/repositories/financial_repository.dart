import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/financial_safety.dart';
import 'repository_base.dart';

/// Server-backed repository for MORT Earnings Safety.
///
/// All totals come from the server (canonical source: completed applications
/// joined to their jobs). Reaching a financial threshold never blocks any
/// marketplace capability — nothing in this repository gates work. No SSN or
/// tax-identity data is collected anywhere in these calls.
class FinancialRepository extends RepositoryBase {
  FinancialRepository({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  static const receiptsBucket = 'financial-receipts';
  static const maxReceiptBytes = 10 * 1024 * 1024;

  final ImagePicker _picker;

  // -- Earnings summary (canonical server-side calculation) ----------------

  Future<FinancialSummary> getFinancialSummary(int year) async {
    final response = await client.rpc(
      'get_my_financial_summary',
      params: {'p_year': year},
    );
    final data = _ok(response, 'financial_summary_unavailable');
    return FinancialSummary.fromJson(data);
  }

  Future<FinancialEvaluation> evaluateAlerts(int year) async {
    final response = await client.rpc(
      'evaluate_my_financial_alerts',
      params: {'p_year': year},
    );
    final data = _ok(response, 'financial_check_unavailable');
    return FinancialEvaluation.fromJson(data);
  }

  Future<List<FinancialRule>> listRules({String? category}) async {
    final response = await client.rpc(
      'list_financial_rules',
      params: category == null ? const {} : {'p_category': category},
    );
    final data = _ok(response, 'financial_rules_unavailable');
    final rules = data['rules'];
    return rules is List
        ? rules
              .whereType<Map>()
              .map(
                (item) =>
                    FinancialRule.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false)
        : const [];
  }

  // -- Expense ledger -------------------------------------------------------

  Future<List<ExpenseRecord>> listExpenses(int year) async {
    final response = await client.rpc(
      'list_my_expenses',
      params: {'p_year': year},
    );
    final data = _ok(response, 'expenses_unavailable');
    final expenses = data['expenses'];
    return expenses is List
        ? expenses
              .whereType<Map>()
              .map(
                (item) =>
                    ExpenseRecord.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false)
        : const [];
  }

  Future<ExpenseRecord> createExpense({
    required int amountCents,
    required DateTime spentOn,
    required ExpenseCategory category,
    String merchant = '',
    String description = '',
    String? jobId,
    String notes = '',
  }) async {
    final response = await client.rpc(
      'create_my_expense',
      params: {
        'p_amount_cents': amountCents,
        'p_spent_on': _dateString(spentOn),
        'p_category': category.wire,
        'p_merchant': merchant,
        'p_description': description,
        'p_job_id': jobId,
        'p_notes': notes,
      },
    );
    final data = _ok(response, 'expense_not_saved');
    return ExpenseRecord.fromJson(
      Map<String, dynamic>.from(data['expense'] as Map),
    );
  }

  Future<ExpenseRecord> updateExpense(
    String expenseId, {
    int? amountCents,
    DateTime? spentOn,
    ExpenseCategory? category,
    String? merchant,
    String? description,
    String? jobId,
    bool clearJob = false,
    String? notes,
  }) async {
    final response = await client.rpc(
      'update_my_expense',
      params: {
        'p_id': expenseId,
        'p_amount_cents': amountCents,
        'p_spent_on': spentOn == null ? null : _dateString(spentOn),
        'p_category': category?.wire,
        'p_merchant': merchant,
        'p_description': description,
        'p_job_id': jobId,
        'p_clear_job': clearJob,
        'p_notes': notes,
      },
    );
    final data = _ok(response, 'expense_not_saved');
    return ExpenseRecord.fromJson(
      Map<String, dynamic>.from(data['expense'] as Map),
    );
  }

  Future<void> deleteExpense(String expenseId) async {
    final response = await client.rpc(
      'delete_my_expense',
      params: {'p_id': expenseId},
    );
    _ok(response, 'expense_not_deleted');
  }

  // -- Receipts (private storage, owner-only RLS) ---------------------------

  Future<XFile?> chooseReceiptPhoto({
    ImageSource source = ImageSource.gallery,
  }) {
    try {
      return _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
        requestFullMetadata: false,
      );
    } catch (_) {
      throw const ReceiptPickerUnavailable();
    }
  }

  /// Uploads a receipt into the caller's own private folder and registers the
  /// path on the expense. The server rejects paths outside the owner folder.
  Future<String> attachReceipt(
    XFile file,
    String expenseId, {
    Uint8List? bytes,
  }) async {
    final userId = requireUserId();
    final data = bytes ?? await file.readAsBytes();
    if (data.isEmpty || data.length > maxReceiptBytes) {
      throw const ReceiptTooLarge();
    }
    final extension = _safeExtension(file.name);
    final path = '$userId/${const Uuid().v4()}.$extension';

    try {
      await client.storage
          .from(receiptsBucket)
          .uploadBinary(
            path,
            data,
            fileOptions: FileOptions(
              contentType: _contentType(extension),
              cacheControl: '3600',
              upsert: false,
            ),
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      await recordUploadFailure(
        uploadKind: 'financial_receipt',
        safeCode: 'financial_receipt_upload_failed',
      );
      rethrow;
    }

    final response = await client.rpc(
      'set_my_expense_receipt',
      params: {'p_id': expenseId, 'p_path': path},
    );
    try {
      _ok(response, 'receipt_not_registered');
    } catch (_) {
      // The object must not stay orphaned if registration failed.
      try {
        await client.storage.from(receiptsBucket).remove([path]);
      } catch (_) {
        // Registration failure is the primary error; keep rethrowing it.
      }
      rethrow;
    }
    return path;
  }

  Future<void> removeReceipt(String expenseId, String path) async {
    await client.rpc(
      'set_my_expense_receipt',
      params: {'p_id': expenseId, 'p_path': null},
    );
    try {
      await client.storage.from(receiptsBucket).remove([path]);
    } catch (_) {
      // The stored record is already cleared; a stale object is harmless and
      // remains owner-only accessible.
    }
  }

  /// Short-lived signed URL for the receipt preview. Only the owner can mint
  /// or use it (storage RLS is owner-only).
  Future<String?> signedReceiptUrl(String path) async {
    try {
      return await client.storage
          .from(receiptsBucket)
          .createSignedUrl(path, 300);
    } catch (_) {
      return null;
    }
  }

  // -- Preferences, targets -------------------------------------------------

  Future<FinancialPreferences> getPreferences() async {
    final response = await client.rpc('get_my_financial_preferences');
    final data = _ok(response, 'financial_preferences_unavailable');
    return FinancialPreferences.fromJson(
      Map<String, dynamic>.from(data['preferences'] as Map),
    );
  }

  Future<FinancialPreferences> setPreferences({
    bool? alertsEnabled,
    List<String>? benefitPrograms,
    bool? guardianFinancialVisibility,
  }) async {
    final response = await client.rpc(
      'set_my_financial_preferences',
      params: {
        'p_alerts_enabled': alertsEnabled,
        'p_benefit_programs': benefitPrograms,
        'p_guardian_financial_visibility': guardianFinancialVisibility,
      },
    );
    final data = _ok(response, 'financial_preferences_not_saved');
    return FinancialPreferences.fromJson(
      Map<String, dynamic>.from(data['preferences'] as Map),
    );
  }

  Future<FinancialPersonalTarget> upsertTarget({
    required int year,
    required int amountCents,
    String label = 'Personal earning target',
  }) async {
    final response = await client.rpc(
      'upsert_my_financial_target',
      params: {'p_year': year, 'p_amount_cents': amountCents, 'p_label': label},
    );
    final data = _ok(response, 'target_not_saved');
    return FinancialPersonalTarget.fromJson(
      Map<String, dynamic>.from(data['target'] as Map),
    );
  }

  Future<void> deleteTarget(int year) async {
    final response = await client.rpc(
      'delete_my_financial_target',
      params: {'p_year': year},
    );
    _ok(response, 'target_not_deleted');
  }

  // -- Exports --------------------------------------------------------------

  Future<FinancialYearReport> getYearReport(int year) async {
    final response = await client.rpc(
      'get_my_financial_year_report',
      params: {'p_year': year},
    );
    final data = _ok(response, 'financial_report_unavailable');
    return FinancialYearReport.fromJson(data);
  }

  /// Parses an RPC response, enforcing the server's `ok` flag. Fail-closed:
  /// anything unexpected becomes a user-actionable error instead of silent
  /// fake data.
  Map<String, dynamic> _ok(dynamic response, String safeMessage) {
    if (response is! Map) {
      throw StateError(safeMessage);
    }
    final data = Map<String, dynamic>.from(response);
    if (data['ok'] != true) {
      throw StateError(data['code']?.toString() ?? safeMessage);
    }
    return data;
  }

  String _dateString(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  String _safeExtension(String name) {
    final match = RegExp(r'\.([A-Za-z0-9]{1,5})$').firstMatch(name.trim());
    final extension = match?.group(1)?.toLowerCase() ?? 'jpg';
    return switch (extension) {
      'jpg' || 'jpeg' => 'jpg',
      'png' => 'png',
      'webp' => 'webp',
      'pdf' => 'pdf',
      _ => 'jpg',
    };
  }

  String _contentType(String extension) => switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    _ => 'image/jpeg',
  };
}

class ReceiptTooLarge implements Exception {
  const ReceiptTooLarge();

  @override
  String toString() =>
      'That receipt is too large. Use a file of 10 MB or less.';
}

class ReceiptPickerUnavailable implements Exception {
  const ReceiptPickerUnavailable();

  @override
  String toString() =>
      'The photo picker is unavailable right now. Try again later.';
}
