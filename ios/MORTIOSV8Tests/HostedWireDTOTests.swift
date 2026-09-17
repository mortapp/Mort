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
