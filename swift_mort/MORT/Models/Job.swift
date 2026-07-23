import Foundation

enum JobSort: String, CaseIterable, Identifiable, Sendable {
    case newest
    case highestPay
    case soonestStart

    var id: String { rawValue }
    var title: String {
        switch self {
        case .newest: "Newest"
        case .highestPay: "Highest pay"
        case .soonestStart: "Soonest start"
        }
    }
}

struct JobSearchFilters: Equatable, Sendable {
    var keyword = ""
    var category: String?
    var minimumPayCents: Int?
    var paymentType: String?
    var scheduleType: String?
    var verificationRequirement: String?
    var requiresGuardianApproval: Bool?
    var workEnvironment: String?
    var sort: JobSort = .newest
}

struct Job: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let posterID: UUID
    let title: String
    let summary: String?
    let description: String
    let category: String
    let locationText: String
    let city: String
    let state: String
    let status: String
    let requiresGuardianApproval: Bool
    let payAmountCents: Int?
    let payLabel: String?
    let startsAt: String?
    let endsAt: String?
    let deadlineAt: String?
    let expiresAt: String?
    let publishedAt: String?
    let poster: ProfileSummary?
    let scheduleType: String
    let paymentType: String
    let paymentMethod: String
    let paymentTiming: String
    let verificationRequirement: String
    let workEnvironment: String
    let locationType: String
    let experienceLevel: String
    let estimatedDurationMinutes: Int?
    let workersNeeded: Int
    let skillsNeeded: [String]
    let physicalRequirements: [String]
    let equipmentProvided: String?
    let equipmentWorkerBrings: String?
    let specialInstructions: String?
    let safetyNotes: String?
    let proofExpected: Bool
    let adultSupervisionPresent: Bool
    let tipAllowed: Bool
    let applicationsOpen: Bool
    let isTest: Bool
    let recurring: Bool
    let recurrenceRule: String?
    let timezone: String
    let urgency: String
    let neighborhood: String?
    let zipCode: String?
    let travelRadiusMiles: Int?
    let teenMinAge: Int
    let teenMaxAge: Int

    enum CodingKeys: String, CodingKey {
        case id, title, summary, description, category, city, state, status
        case posterID = "poster_id"
        case locationText = "location_text"
        case requiresGuardianApproval = "requires_guardian_approval"
        case payAmountCents = "pay_amount_cents"
        case payLabel = "pay_label"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case deadlineAt = "deadline_at"
        case expiresAt = "expires_at"
        case publishedAt = "published_at"
        case poster = "profiles"
        case scheduleType = "schedule_type"
        case paymentType = "payment_type"
        case paymentMethod = "payment_method"
        case paymentTiming = "payment_timing"
        case verificationRequirement = "verification_requirement"
        case workEnvironment = "work_environment"
        case locationType = "location_type"
        case experienceLevel = "experience_level"
        case estimatedDurationMinutes = "estimated_duration_minutes"
        case workersNeeded = "workers_needed"
        case skillsNeeded = "skills_needed"
        case physicalRequirements = "physical_requirements"
        case equipmentProvided = "equipment_provided"
        case equipmentWorkerBrings = "equipment_worker_brings"
        case specialInstructions = "special_instructions"
        case safetyNotes = "safety_notes"
        case proofExpected = "proof_expected"
        case adultSupervisionPresent = "adult_supervision_present"
        case tipAllowed = "tip_allowed"
        case applicationsOpen = "applications_open"
        case isTest = "is_test"
        case recurring
        case recurrenceRule = "recurrence_rule"
        case timezone, urgency, neighborhood
        case zipCode = "zip_code"
        case travelRadiusMiles = "travel_radius_miles"
        case teenMinAge = "teen_min_age"
        case teenMaxAge = "teen_max_age"
    }

    var isOpen: Bool { status == "open" && applicationsOpen }
    var posterVerified: Bool { !isTest && poster?.verificationStatus == "approved" }
    var payDisplay: String {
        if let payAmountCents { return payAmountCents.formattedCurrency }
        return payLabel?.nilIfBlank ?? "Pay discussed in-app"
    }
    var scheduleDisplay: String {
        guard scheduleType != "flexible", let startsAt else { return "Flexible schedule" }
        return DateFormatting.displayDateTime(startsAt)
    }
}

struct SavedJobEnvelope: Decodable, Sendable {
    let createdAt: String?
    let job: Job?

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case job = "jobs"
    }
}

struct JobDraft: Equatable, Sendable {
    var id: UUID?
    var clientRequestID = UUID()
    var title = ""
    var summary = ""
    var description = ""
    var category = "cleaning"
    var estimatedDurationMinutes: Int?
    var workersNeeded = 1
    var experienceLevel = "any"
    var skillsNeeded: [String] = []
    var equipmentProvided = ""
    var equipmentWorkerBrings = ""
    var physicalRequirements: [String] = []
    var proofExpected = false
    var specialInstructions = ""
    var scheduleType = "flexible"
    var startsAt: Date?
    var endsAt: Date?
    var deadlineAt: Date?
    var recurring = false
    var recurrenceRule = ""
    var timezone = "America/Indianapolis"
    var urgency = "normal"
    var locationText = ""
    var city = ""
    var state = ""
    var neighborhood = ""
    var zipCode = ""
    var travelRadiusMiles: Int?
    var workEnvironment = "unspecified"
    var locationType = "unspecified"
    var payAmountCents: Int?
    var paymentType = "fixed"
    var paymentMethod = "flexible"
    var paymentTiming = "after_completion"
    var tipAllowed = false
    var teenMinAge = 13
    var teenMaxAge = 17
    var adultSupervisionPresent = false
    var verificationRequirement = "none"
    var requiresGuardianApproval = false
    var safetyNotes = ""

    var payload: JobPayload {
        JobPayload(
            title: title.trimmed,
            summary: summary.trimmed,
            description: description.trimmed,
            category: category,
            estimatedDurationMinutes: estimatedDurationMinutes,
            workersNeeded: workersNeeded,
            experienceLevel: experienceLevel,
            skillsNeeded: skillsNeeded,
            equipmentProvided: equipmentProvided.nilIfBlank,
            equipmentWorkerBrings: equipmentWorkerBrings.nilIfBlank,
            physicalRequirements: physicalRequirements,
            proofExpected: proofExpected,
            specialInstructions: specialInstructions.nilIfBlank,
            scheduleType: scheduleType,
            startsAt: startsAt?.iso8601String,
            endsAt: endsAt?.iso8601String,
            deadlineAt: deadlineAt?.iso8601String,
            recurring: recurring,
            recurrenceRule: recurrenceRule.nilIfBlank,
            timezone: timezone,
            urgency: urgency,
            locationText: locationText.trimmed,
            city: city.trimmed,
            state: state.trimmed.uppercased(),
            neighborhood: neighborhood.nilIfBlank,
            zipCode: zipCode.nilIfBlank,
            travelRadiusMiles: travelRadiusMiles,
            workEnvironment: workEnvironment,
            locationType: locationType,
            payAmountCents: payAmountCents,
            paymentType: paymentType,
            paymentMethod: paymentMethod,
            paymentTiming: paymentTiming,
            tipAllowed: tipAllowed,
            teenMinAge: teenMinAge,
            teenMaxAge: teenMaxAge,
            adultSupervisionPresent: adultSupervisionPresent,
            verificationRequirement: verificationRequirement,
            requiresGuardianApproval: requiresGuardianApproval,
            safetyNotes: safetyNotes.nilIfBlank
        )
    }
}

struct JobPayload: Encodable, Sendable {
    let title: String
    let summary: String
    let description: String
    let category: String
    let estimatedDurationMinutes: Int?
    let workersNeeded: Int
    let experienceLevel: String
    let skillsNeeded: [String]
    let equipmentProvided: String?
    let equipmentWorkerBrings: String?
    let physicalRequirements: [String]
    let proofExpected: Bool
    let specialInstructions: String?
    let scheduleType: String
    let startsAt: String?
    let endsAt: String?
    let deadlineAt: String?
    let recurring: Bool
    let recurrenceRule: String?
    let timezone: String
    let urgency: String
    let locationText: String
    let city: String
    let state: String
    let neighborhood: String?
    let zipCode: String?
    let travelRadiusMiles: Int?
    let workEnvironment: String
    let locationType: String
    let payAmountCents: Int?
    let paymentType: String
    let paymentMethod: String
    let paymentTiming: String
    let tipAllowed: Bool
    let teenMinAge: Int
    let teenMaxAge: Int
    let adultSupervisionPresent: Bool
    let verificationRequirement: String
    let requiresGuardianApproval: Bool
    let safetyNotes: String?

    enum CodingKeys: String, CodingKey {
        case title, summary, description, category, recurring, timezone, urgency, city, state, neighborhood
        case estimatedDurationMinutes = "estimated_duration_minutes"
        case workersNeeded = "workers_needed"
        case experienceLevel = "experience_level"
        case skillsNeeded = "skills_needed"
        case equipmentProvided = "equipment_provided"
        case equipmentWorkerBrings = "equipment_worker_brings"
        case physicalRequirements = "physical_requirements"
        case proofExpected = "proof_expected"
        case specialInstructions = "special_instructions"
        case scheduleType = "schedule_type"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case deadlineAt = "deadline_at"
        case recurrenceRule = "recurrence_rule"
        case locationText = "location_text"
        case zipCode = "zip_code"
        case travelRadiusMiles = "travel_radius_miles"
        case workEnvironment = "work_environment"
        case locationType = "location_type"
        case payAmountCents = "pay_amount_cents"
        case paymentType = "payment_type"
        case paymentMethod = "payment_method"
        case paymentTiming = "payment_timing"
        case tipAllowed = "tip_allowed"
        case teenMinAge = "teen_min_age"
        case teenMaxAge = "teen_max_age"
        case adultSupervisionPresent = "adult_supervision_present"
        case verificationRequirement = "verification_requirement"
        case requiresGuardianApproval = "requires_guardian_approval"
        case safetyNotes = "safety_notes"
    }
}

struct JobStatusEvent: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let jobID: UUID
    let fromStatus: String?
    let toStatus: String
    let actorID: UUID?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case jobID = "job_id"
        case fromStatus = "from_status"
        case toStatus = "to_status"
        case actorID = "actor_id"
        case createdAt = "created_at"
    }
}
