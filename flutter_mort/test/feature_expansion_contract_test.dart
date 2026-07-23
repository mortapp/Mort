import 'package:flutter_mort/core/errors/user_facing_error.dart';
import 'package:flutter_mort/data/models/message.dart';
import 'package:flutter_mort/data/models/proof.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('message thread parses server-authoritative unread state', () {
    final thread = MessageThread.fromMap({
      'id': 'thread-id',
      'job_id': 'job-id',
      'updated_at': '2026-07-17T08:00:00Z',
      'unread_count': 3,
    });

    expect(thread.unreadCount, 3);
    expect(thread.updatedAt, DateTime.utc(2026, 7, 17, 8));
  });

  test('missing unread state degrades safely to zero', () {
    final thread = MessageThread.fromMap({'id': 'legacy-thread'});
    expect(thread.unreadCount, 0);
  });

  test('proof review model exposes honest status labels', () {
    final proof = ProofUpload.fromMap({
      'id': 'proof-id',
      'application_id': 'application-id',
      'uploaded_by': 'teen-id',
      'storage_path': 'teen-id/proof-id.jpg',
      'status': 'resubmission_requested',
      'review_note': 'Please show the completed shelf labels.',
    });

    expect(proof.statusLabel, 'New proof requested');
    expect(proof.reviewNote, contains('completed shelf'));
  });

  test('proof completion errors explain the required next action', () {
    expect(
      applicationErrorMessage('proof_approval_required'),
      'Approve the submitted proof before marking this job complete.',
    );
    expect(
      applicationErrorMessage('proof_review_note_required'),
      contains('10 characters'),
    );
  });
}
