//
//  HostedWireDTOTests.swift
//  MORT iOS V8
//
//  Decoding fixtures mirror the actual hosted Supabase JSON contracts.
//  These are intentionally not Rork-era placeholder field names.
//

import Foundation
import Testing
@testable import MORTIOSV8

struct HostedWireDTOTests {
    @Test("Hosted profile JSON maps to the privacy-safe MORT user model")
    func profileMapping() throws {
        let json = #"""
        {
          "id": "11111111-1111-4111-8111-111111111111",
          "role": "teen",
          "display_name": "Michael R.",
          "city": "Indianapolis",
          "state": "IN",
          "created_at": "2026-09-01T12:00:00Z",
          "updated_at": "2026-09-17T12:00:00Z",
          "username": "sosa",
          "guardian_setup_status": "linked",
          "verification_status": "approved",
          "bio": "Local teen worker",
          "preferred_job_categories": ["yard_work", "pet_care"],
          "approximate_area": "Northside"
        }
        """#.data(using: .utf8)!

        let dto = try hostedDecoder().decode(HostedProfileDTO.self, from: json)
        let user = dto.toDomain()

        #expect(user.id == "11111111-1111-4111-8111-111111111111")
        #expect(user.handle == "@sosa")
        #expect(user.displayName == "Michael R.")
        #expect(user.role == .teen)
        #expect(user.area == "Northside")
        #expect(user.guardianLinked)
        #expect(user.bio == "Local teen worker")
        #expect(user.rating == nil)
        #expect(user.completedJobs == 0)
    }

    @Test("Hosted profile falls back to city/state and never invents reputation")
    func profileFallbacks() throws {
        let json = #"""
        {
          "id": "22222222-2222-4222-8222-222222222222",
          "role": "adult",
          "display_name": "Jordan P.",
          "city": "Indianapolis",
          "state": "IN",
          "created_at": "2026-09-01T12:00:00Z",
          "updated_at": "2026-09-17T12:00:00Z",
          "username": "jordan",
          "guardian_setup_status": "not_started",
          "verification_status": "not_started",
          "bio": null,
          "preferred_job_categories": [],
          "approximate_area": null
        }
        """#.data(using: .utf8)!

        let user = try hostedDecoder().decode(HostedProfileDTO.self, from: json).toDomain()
        #expect(user.area == "Indianapolis, IN")
        #expect(user.rating == nil)
        #expect(user.verifications.isEmpty)
        #expect(!user.guardianLinked)
    }
}

private func hostedDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}


struct HostedJobFeedDTOTests {
    @Test("Hosted open-job page preserves authoritative pay, area and opaque cursor")
    func openJobPageMapping() throws {
        let json = #"""
        {
          "ok": true,
          "items": [
            {
              "id": "33333333-3333-4333-8333-333333333333",
              "poster_id": "44444444-4444-4444-8444-444444444444",
              "title": "Mow front and back yard",
              "description": "Mow both yards and bag the clippings.",
              "summary": "Yard mowing",
              "category": "yard_work",
              "location_text": "Northside, Indianapolis",
              "city": "Indianapolis",
              "state": "IN",
              "neighborhood": "Northside",
              "pay_amount_cents": 2400,
              "status": "open",
              "starts_at": "2026-09-20T14:00:00Z",
              "created_at": "2026-09-17T18:30:00Z",
              "proof_expected": true,
              "schedule_type": "exact",
              "profiles": {
                "display_name": "Jordan P.",
                "verification_status": "approved",
                "avatar_path": null
              },
              "distance_status": "unavailable",
              "match_explanation": "Distance is not calculated."
            }
          ],
          "has_more": true,
          "next_cursor": {
            "value": "2026-09-17T18:30:00+00:00",
            "id": "33333333-3333-4333-8333-333333333333"
          },
          "distance_calculated": false,
          "location_precision": "general_area_only"
        }
        """#.data(using: .utf8)!

        let page = try hostedDecoder().decode(HostedJobFeedPageDTO.self, from: json)
        let job = try #require(page.items.first).toDomain()

        #expect(page.ok)
        #expect(job.id == "33333333-3333-4333-8333-333333333333")
        #expect(job.title == "Mow front and back yard")
        #expect(job.baseCents == 2400)
        #expect(job.area == "Northside")
        #expect(job.posterDisplayName == "Jordan P.")
        #expect(job.state == .open)
        #expect(job.requiresProof)
        #expect(job.distance == "Distance unavailable")

        let opaque = try #require(page.nextCursor?.opaqueValue)
        let decoded = try #require(HostedJobCursorDTO(opaqueValue: opaque))
        #expect(decoded.value == "2026-09-17T18:30:00+00:00")
        #expect(decoded.id == "33333333-3333-4333-8333-333333333333")
    }

    @Test("Hosted job cursors reject malformed client state")
    func cursorRejectsMalformedInput() {
        #expect(HostedJobCursorDTO(opaqueValue: "not-a-valid-cursor") == nil)
    }
}


struct HostedPaymentOSDTOTests {
    @Test("Hosted funding quote preserves server-authoritative cents and expiry")
    func fundingQuoteDecodes() throws {
        let json = #"""
        {
          "ok": true,
          "quote_id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
          "contract_id": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
          "base_pay_cents": 2400,
          "service_fee_cents": 192,
          "authoritative_total_cents": 2592,
          "currency_code": "USD",
          "fair_pay_decision": "GREEN",
          "state": "ACTIVE",
          "created_at": "2026-09-18T00:00:00Z",
          "expires_at": "2026-09-18T00:15:00Z",
          "idempotent": false
        }
        """#.data(using: .utf8)!

        let quote = try hostedDecoder().decode(HostedFundingQuoteResponseDTO.self, from: json)
        #expect(quote.ok)
        #expect(quote.quoteId == "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        #expect(quote.contractId == "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        #expect(quote.basePayCents == 2400)
        #expect(quote.serviceFeeCents == 192)
        #expect(quote.authoritativeTotalCents == 2592)
        #expect(quote.state == "ACTIVE")
        #expect(quote.expiresAt != nil)
    }

    @Test("Hosted PaymentIntent response derives only the provider pi id from its client secret")
    func paymentIntentProviderReference() throws {
        let json = #"""
        {
          "ok": true,
          "payment_intent_id": "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
          "payment_attempt_id": "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
          "environment": "test",
          "publishable_key": "pk_test_example",
          "payment_intent_client_secret": "pi_12345_secret_shortlived",
          "customer_id": "cus_123",
          "customer_ephemeral_key_secret": "ek_test_shortlived",
          "base_pay_cents": 2400,
          "service_fee_cents": 192,
          "total_amount_cents": 2592,
          "currency_code": "USD"
        }
        """#.data(using: .utf8)!

        let intent = try hostedDecoder().decode(HostedPaymentIntentResponseDTO.self, from: json)
        #expect(intent.ok)
        #expect(intent.providerPaymentIntentId == "pi_12345")
        #expect(intent.totalAmountCents == 2592)
    }

    @Test("Hosted normalized payment state never promotes processing to funded")
    func paymentStateMapping() {
        #expect(HostedPaymentStateMapper.normalized("SUCCEEDED") == .funded)
        #expect(HostedPaymentStateMapper.normalized("PROCESSING") == .processing)
        #expect(HostedPaymentStateMapper.normalized("REQUIRES_ACTION") == .requiresAction)
        #expect(HostedPaymentStateMapper.normalized("DECLINED") == .declined)
        #expect(HostedPaymentStateMapper.normalized("FAILED") == .unknown)
        #expect(HostedPaymentStateMapper.normalized("something_new") == .unknown)
    }

    @Test("Legacy recovery status prevents blind double-charge after known funding")
    func legacyRecoveryMapping() {
        #expect(HostedPaymentStateMapper.legacyFundingStatus("funded") == .funded)
        #expect(HostedPaymentStateMapper.legacyFundingStatus("transferred") == .funded)
        #expect(HostedPaymentStateMapper.legacyFundingStatus("partially_refunded") == .funded)
        #expect(HostedPaymentStateMapper.legacyFundingStatus("processing") == .processing)
        #expect(HostedPaymentStateMapper.legacyFundingStatus("funding_failed") == .unknown)
    }
}


struct HostedJobRecordDTOTests {
    @Test("Hosted job record maps lifecycle and privacy-safe location")
    func jobRecordMapping() throws {
        let json = #"""
        {
          "id": "33333333-3333-4333-8333-333333333333",
          "poster_id": "44444444-4444-4444-8444-444444444444",
          "title": "Mow the yard",
          "summary": "Front and back yard mowing",
          "description": "Mow both yards and bag the clippings when finished.",
          "category": "lawn care",
          "location_text": "General northside area",
          "city": "Indianapolis",
          "state": "IN",
          "neighborhood": "Northside",
          "pay_amount_cents": 2400,
          "status": "in_progress",
          "starts_at": "2026-09-20T14:00:00Z",
          "created_at": "2026-09-17T18:30:00Z",
          "updated_at": "2026-09-18T00:00:00Z",
          "proof_expected": true,
          "schedule_type": "exact",
          "applications_open": false
        }
        """#.data(using: .utf8)!

        let dto = try hostedDecoder().decode(HostedJobRecordDTO.self, from: json)
        let job = try dto.toDomain(posterHandle: "@jordan", posterDisplayName: "Jordan P.")
        #expect(job.state == .inProgress)
        #expect(job.baseCents == 2400)
        #expect(job.area == "Northside")
        #expect(job.posterHandle == "@jordan")
        #expect(job.requiresProof)
    }
}

struct HostedFinancialDocumentDTOTests {
    @Test("Immutable teen earnings document maps to receipt and timeline without inventing bank payout")
    func teenEarningsMapping() throws {
        let json = #"""
        {
          "id": "55555555-5555-4555-8555-555555555555",
          "document_type": "TEEN_EARNINGS",
          "receipt_id": "K-260918-00042",
          "order_number": "0042",
          "document_date": "2026-09-18",
          "amount_cents": 2400,
          "currency_code": "USD",
          "status": "succeeded",
          "masked_provider_reference": "ch_4242",
          "immutable_snapshot": {
            "job_title": "Mow the yard",
            "display_username": "sosa",
            "service_description": "Yard mowing service"
          },
          "linked_document_refs": ["Q-260918-00041"],
          "created_at": "2026-09-18T00:30:00Z"
        }
        """#.data(using: .utf8)!

        let dto = try hostedDecoder().decode(HostedFinancialDocumentDTO.self, from: json)
        let receipt = dto.toReceipt()
        let history = dto.toHistoryRecord()

        #expect(receipt.type == .teenEarnings)
        #expect(receipt.id == "K-260918-00042")
        #expect(receipt.orderNumber == "0042")
        #expect(receipt.lines.first?.amountCents == 2400)
        #expect(receipt.notATaxDocumentNote != nil)
        #expect(history.kind == .earning)
        #expect(history.amountCents == 2400)
        #expect(history.receiptNumber == "K-260918-00042")
    }

    @Test("Adult payment timeline amount is an outflow")
    func adultPaymentSign() throws {
        let json = #"""
        {
          "id": "66666666-6666-4666-8666-666666666666",
          "document_type": "ADULT_JOB_PAYMENT",
          "receipt_id": "M-260918-00043",
          "order_number": "0043",
          "document_date": "2026-09-18",
          "amount_cents": 2592,
          "currency_code": "USD",
          "status": "succeeded",
          "masked_provider_reference": "ch_4242",
          "immutable_snapshot": {},
          "linked_document_refs": [],
          "created_at": "2026-09-18T00:31:00Z"
        }
        """#.data(using: .utf8)!

        let dto = try hostedDecoder().decode(HostedFinancialDocumentDTO.self, from: json)
        #expect(dto.toHistoryRecord().amountCents == -2592)
        #expect(dto.toReceipt().type == .adultJobPayment)
    }
}

struct HostedPayoutStatusDTOTests {
    @Test("Hosted payout status distinguishes provider readiness from bank settlement")
    func payoutMapping() throws {
        let json = #"""
        {
          "status": "complete",
          "details_submitted": true,
          "payouts_enabled": true,
          "transfers_status": "active",
          "requirements_status": "satisfied",
          "guardian_requirement_status": "not_required",
          "disabled_reason_code": null,
          "country": "US",
          "default_currency": "usd",
          "last_synchronized_at": "2026-09-18T00:00:00Z",
          "latest_payout": null,
          "provider": "stripe"
        }
        """#.data(using: .utf8)!

        let dto = try hostedDecoder().decode(HostedStripePayoutStatusDTO.self, from: json)
        #expect(dto.stage == .ready)
        #expect(!dto.toDomain().stage.isMoneyInBank)
    }
}


struct HostedCompletionDTOTests {
    @Test("Hosted execution status exposes the authoritative contract and start time")
    func executionStatusDecodes() throws {
        let json = #"""
        {
          "ok": true,
          "application_id": "11111111-1111-4111-8111-111111111111",
          "job_id": "22222222-2222-4222-8222-222222222222",
          "contract_id": "33333333-3333-4333-8333-333333333333",
          "role": "teen",
          "state": "in_progress",
          "start_pin_active": false,
          "started_at": "2026-09-18T01:00:00Z",
          "funding_status": "succeeded",
          "live_payment_enabled": false
        }
        """#.data(using: .utf8)!

        let dto = try hostedDecoder().decode(HostedExecutionStatusDTO.self, from: json)
        #expect(dto.ok)
        #expect(dto.contractId == "33333333-3333-4333-8333-333333333333")
        #expect(dto.startedAt != nil)
        #expect(dto.state == "in_progress")
    }

    @Test("Hosted completion assertion response stays separate from settlement")
    func completionAssertionDecodes() throws {
        let json = #"""
        {
          "ok": true,
          "assertion_id": "44444444-4444-4444-8444-444444444444",
          "adult_acknowledgment_still_required": true
        }
        """#.data(using: .utf8)!

        let dto = try hostedDecoder().decode(HostedCompletionAssertionResponseDTO.self, from: json)
        #expect(dto.ok)
        #expect(dto.assertionId == "44444444-4444-4444-8444-444444444444")
        #expect(dto.adultAcknowledgmentStillRequired == true)
    }
}


struct HostedAdultCompletionDTOTests {
    @Test("Adult completion acknowledgement does not pretend settlement ran")
    func acknowledgementDecodes() throws {
        let json = #"""
        {
          "ok": true,
          "assertion_id": "55555555-5555-4555-8555-555555555555",
          "payment_due": true,
          "mort_processed_payment": false
        }
        """#.data(using: .utf8)!

        let dto = try hostedDecoder().decode(HostedAdultCompletionResponseDTO.self, from: json)
        #expect(dto.ok)
        #expect(dto.assertionId == "55555555-5555-4555-8555-555555555555")
        #expect(dto.paymentDue == true)
        #expect(dto.mortProcessedPayment == false)
    }
}
