import { createHash } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const outputDirectory = join(root, "docs", "legal-research");
const retrievalDate = "2026-07-19";

const categoryTargets = {
  local_task_marketplaces: 20,
  freelance_marketplaces: 20,
  household_service_marketplaces: 20,
  pet_care_marketplaces: 15,
  childcare_caregiving_services: 15,
  transportation_delivery_platforms: 20,
  social_community_platforms: 20,
  youth_education_school_platforms: 20,
  workforce_employment_platforms: 20,
  payment_financial_platforms: 20,
  safety_family_location_products: 15,
  housing_hospitality_platforms: 15,
  seller_resale_marketplaces: 15,
  identity_verification_providers: 15,
  nonprofit_youth_service_programs: 15,
  government_regulatory_materials: 35,
};

const labels = {
  local_task_marketplaces: "Local task marketplaces",
  freelance_marketplaces: "Freelance marketplaces",
  household_service_marketplaces: "Household-service marketplaces",
  pet_care_marketplaces: "Pet-care marketplaces",
  childcare_caregiving_services: "Childcare and caregiving services",
  transportation_delivery_platforms: "Transportation and delivery platforms",
  social_community_platforms: "Social networks and community platforms",
  youth_education_school_platforms: "Youth, education, and school platforms",
  workforce_employment_platforms: "Workforce and employment platforms",
  payment_financial_platforms: "Payment and financial platforms",
  safety_family_location_products: "Safety and family-location products",
  housing_hospitality_platforms: "Housing and hospitality platforms",
  seller_resale_marketplaces: "Seller and resale marketplaces",
  identity_verification_providers: "Identity-verification providers",
  nonprofit_youth_service_programs: "Nonprofit and youth-service programs",
  government_regulatory_materials: "Government and regulatory materials",
};

const roles = {
  local_task_marketplaces: "worker, customer, platform operator",
  freelance_marketplaces: "freelancer, client, platform operator",
  household_service_marketplaces: "service provider, household customer, platform operator",
  pet_care_marketplaces: "pet caregiver, pet owner, platform operator",
  childcare_caregiving_services: "caregiver, family, minor participant, platform operator",
  transportation_delivery_platforms: "driver, courier, customer, platform operator",
  social_community_platforms: "member, moderator, minor user, platform operator",
  youth_education_school_platforms: "student, parent, educator, school, platform operator",
  workforce_employment_platforms: "worker, applicant, employer, platform operator",
  payment_financial_platforms: "payer, payee, account holder, payment provider",
  safety_family_location_products: "family member, minor user, trusted contact, service operator",
  housing_hospitality_platforms: "guest, host, property operator, platform operator",
  seller_resale_marketplaces: "seller, buyer, marketplace operator",
  identity_verification_providers: "data subject, relying party, reviewer, verification provider",
  nonprofit_youth_service_programs: "youth participant, family, volunteer, staff member, nonprofit",
  government_regulatory_materials: "minor worker, employer, platform operator, reviewer, regulator",
};

const categoryLessons = {
  local_task_marketplaces: "Use job-specific scope, payment, cancellation, safety, evidence, and dispute records instead of treating a generic platform agreement as the whole transaction.",
  freelance_marketplaces: "Keep immutable work terms and change orders, preserve payment evidence, and distinguish platform process from a court or employment-classification decision.",
  household_service_marketplaces: "Disclose household-entry risk, people present, equipment, insurance limits, and cancellation paths without promising that screening eliminates danger.",
  pet_care_marketplaces: "Pair clear care scope and emergency instructions with private dispute handling, evidence preservation, and bounded protection disclosures.",
  childcare_caregiving_services: "Use plain language, strong safeguarding, careful background-check wording, age-aware privacy, and escalation paths that do not blame victims.",
  transportation_delivery_platforms: "Separate platform, worker, customer, timing, payment, location, and safety duties while avoiding a conclusive worker-classification label.",
  social_community_platforms: "Publish enforceable conduct rules, transparent moderation and appeals, child-safety escalation, and narrow lawful-request handling.",
  youth_education_school_platforms: "Present teen-readable summaries, age-aware privacy controls, school-role boundaries, and guardian consent only where law or policy actually requires it.",
  workforce_employment_platforms: "Warn that classification is fact-specific, preserve wage and work records, and condition official remedy links on jurisdiction and relationship.",
  payment_financial_platforms: "State precisely whether money is processed, distinguish preference from receipt, preserve transaction evidence, and provide private dispute and error-resolution paths.",
  safety_family_location_products: "Minimize location collection, make sharing visible and revocable, protect sensitive actions, and explain emergency-service limitations.",
  housing_hospitality_platforms: "Use scoped location release, host and guest duties, cancellation terms, property-risk disclosure, and balanced limitations that preserve nonwaivable rights.",
  seller_resale_marketplaces: "Use seller accountability, fraud reporting, evidence retention, private restrictions, and clear buyer remedies without publishing unproven accusations.",
  identity_verification_providers: "Separate capture quality, extraction, reuse signals, liveness signals, appearance review, and authoritative verification; document retention and biometric limits explicitly.",
  nonprofit_youth_service_programs: "Require safeguarding, confidentiality, training, role approval, incident escalation, and youth-centered alternatives before volunteers access sensitive information.",
  government_regulatory_materials: "Treat labor, privacy, identity, incident, and remedy guidance as jurisdiction-dependent legal inputs requiring qualified review before launch.",
};

const manual = [];
const add = (category, organization, documentTitle, officialSource) =>
  manual.push({ category, organization, documentTitle, officialSource });

// Local task marketplaces: 20.
add("local_task_marketplaces", "Taskrabbit", "Global Terms of Service", "https://support.taskrabbit.com/hc/en-gb/articles/46260465608603-Taskrabbit-Global-Terms-of-Service");
add("local_task_marketplaces", "Taskrabbit", "Global Privacy Policy", "https://support.taskrabbit.com/hc/en-ca/articles/46260411318427-Taskrabbit-Global-Privacy-Policy");
add("local_task_marketplaces", "Taskrabbit", "Platform Acceptable Use Policy", "https://support.taskrabbit.com/hc/en-us/articles/46260475390107-Taskrabbit-Platform-Acceptable-Use-Policy");
add("local_task_marketplaces", "Taskrabbit", "Fees, Payments, and Cancellation Supplemental Terms", "https://support.taskrabbit.com/hc/en-us/articles/46260514951579-Fees-Payments-and-Cancellation-Supplemental-Terms");
add("local_task_marketplaces", "Taskrabbit", "Taskprotect Terms and Conditions", "https://support.taskrabbit.com/hc/en-us/articles/46260436180379-Taskprotect-Terms-Conditions");
add("local_task_marketplaces", "Taskrabbit", "Overview of Trust and Safety", "https://support.taskrabbit.com/hc/en-us/articles/46260491906203-Overview-of-Trust-and-Safety");
add("local_task_marketplaces", "Taskrabbit", "Communication After Task Invite Policy", "https://support.taskrabbit.com/hc/en-us/articles/46260405727771-Communication-After-Task-Invite-Policy");
add("local_task_marketplaces", "Taskrabbit", "Finding Volunteers on Taskrabbit", "https://support.taskrabbit.com/hc/en-us/articles/46260412971931-Finding-Volunteers-on-Taskrabbit");
add("local_task_marketplaces", "Taskrabbit", "Insurance Disclosure", "https://support.taskrabbit.com/hc/en-ca/articles/46260501460891-What-Kind-of-Insurance-Does-Taskrabbit-Offer");
add("local_task_marketplaces", "Taskrabbit", "Tasker Payment Guidance", "https://support.taskrabbit.com/hc/en-gb/articles/46260427597595-How-Do-I-Pay-My-Tasker");
add("local_task_marketplaces", "Thumbtack", "Terms of Use", "https://www.thumbtack.com/terms");
add("local_task_marketplaces", "Thumbtack", "Privacy Policy", "https://www.thumbtack.com/privacy");
add("local_task_marketplaces", "Thumbtack", "Thumbtack Guarantee", "https://www.thumbtack.com/guarantee");
add("local_task_marketplaces", "Thumbtack", "Safety Guidance", "https://www.thumbtack.com/safety");
add("local_task_marketplaces", "Airtasker", "United States Terms and Conditions", "https://www.airtasker.com/us/terms/");
add("local_task_marketplaces", "Airtasker", "United States Privacy Policy", "https://www.airtasker.com/us/privacy/");
add("local_task_marketplaces", "Airtasker", "Community Guidelines", "https://www.airtasker.com/au/community-guidelines/");
add("local_task_marketplaces", "Airtasker", "Membership Terms and Conditions", "https://www.airtasker.com/us/airtasker-membership-terms/");
add("local_task_marketplaces", "Handy", "Terms of Use and User Agreement", "https://www.handy.com/terms");
add("local_task_marketplaces", "Handy", "Privacy Policy", "https://www.handy.com/privacy");

// Freelance marketplaces: 20.
add("freelance_marketplaces", "Upwork", "User Agreement", "https://upwork.pactsafe.io/versions/68b1e4b9879328be022e65b7.pdf");
add("freelance_marketplaces", "Upwork", "Fixed Price Service Contract Escrow Instructions", "https://upwork.pactsafe.io/versions/6920e0b95a2c6fd4b76c22c2.pdf");
add("freelance_marketplaces", "Upwork", "Hourly Contract Payment Process", "https://support.upwork.com/hc/en-us/articles/211067938-How-payments-for-hourly-contracts-work");
add("freelance_marketplaces", "Upwork", "Fixed-Price Payment Protection for Freelancers", "https://support.upwork.com/hc/en-us/articles/211063748-How-Fixed-Price-Payment-Protection-works-for-freelancers-on-Upwork");
add("freelance_marketplaces", "Upwork", "Milestone and Fixed-Price Payment Process", "https://support.upwork.com/hc/en-us/articles/211063718-How-payments-for-milestones-and-fixed-price-contracts-work");
add("freelance_marketplaces", "Upwork", "Payment Protection Overview", "https://support.upwork.com/hc/en-us/articles/211062568-How-Upwork-protects-your-payments");
add("freelance_marketplaces", "Fiverr", "Terms of Service", "https://www.fiverr.com/legal-portal/legal-terms/terms-of-service");
add("freelance_marketplaces", "Fiverr", "Payment Terms of Service", "https://www.fiverr.com/legal-portal/legal-terms/payment-terms-of-service");
add("freelance_marketplaces", "Fiverr", "Privacy Policy", "https://www.fiverr.com/legal-portal/privacy/privacy-policy");
add("freelance_marketplaces", "Fiverr", "Community Standards", "https://help.fiverr.com/hc/en-us/sections/37332647898001-Fiverr-s-Community-Standards");
add("freelance_marketplaces", "Fiverr", "Legal Portal", "https://www.fiverr.com/legal-portal");
add("freelance_marketplaces", "Freelancer", "User Agreement", "https://www.freelancer.com/about/terms");
add("freelance_marketplaces", "Freelancer", "Privacy Policy", "https://www.freelancer.com/about/privacy");
add("freelance_marketplaces", "Freelancer", "Code of Conduct", "https://www.freelancer.com/info/codeofconduct");
add("freelance_marketplaces", "Freelancer", "Fees and Charges", "https://www.freelancer.com/feesandcharges");
add("freelance_marketplaces", "Toptal", "Terms of Use", "https://www.toptal.com/tos");
add("freelance_marketplaces", "Toptal", "Privacy Policy", "https://www.toptal.com/privacy");
add("freelance_marketplaces", "PeoplePerHour", "Terms", "https://www.peopleperhour.com/static/terms");
add("freelance_marketplaces", "PeoplePerHour", "Privacy Policy", "https://www.peopleperhour.com/static/privacy-policy");
add("freelance_marketplaces", "Contra", "Terms of Use", "https://contra.com/policies/terms");

// Household-service marketplaces: 20.
add("household_service_marketplaces", "Care.com", "Terms of Use", "https://www.care.com/about/terms-of-use/");
add("household_service_marketplaces", "Care.com", "Privacy Policy", "https://www.care.com/about/privacy-policy/");
add("household_service_marketplaces", "Care.com", "Background Checks", "https://www.care.com/about/safety/background-checks/");
add("household_service_marketplaces", "Care.com", "Care.com Background Check", "https://www.care.com/about/safety/background-checks/care-com-background-check/");
add("household_service_marketplaces", "Care.com", "Request Booking Additional Terms", "https://www.care.com/media/cms/pdf/booking-terms.pdf");
add("household_service_marketplaces", "Porch", "Terms of Use", "https://porch.com/about/terms/");
add("household_service_marketplaces", "Porch", "Privacy Policy", "https://porch.com/about/privacy/");
add("household_service_marketplaces", "Houzz", "Terms of Use Agreement", "https://www.houzz.com/termsOfUse");
add("household_service_marketplaces", "Houzz", "Privacy Policy", "https://www.houzz.com/privacyPolicy");
add("household_service_marketplaces", "Houzz", "Trade Program Terms and Conditions", "https://www.houzz.com/trade-program-terms");
add("household_service_marketplaces", "HomeAdvisor", "Consumer Terms", "https://www.homeadvisor.com/rfs/terms/consumerTerms.jsp");
add("household_service_marketplaces", "HomeAdvisor", "Service Professional Terms", "https://www.homeadvisor.com/rfs/terms/serviceProfessionalTerms.jsp");
add("household_service_marketplaces", "HomeAdvisor", "Consumer Mobile Privacy Policy", "https://www.homeadvisor.com/mobile/legal/consumerMobilePrivacyPolicy.jsp");
add("household_service_marketplaces", "HomeAdvisor", "Service Request Privacy Policy", "https://www.homeadvisor.com/rfs/servicerequest/exactmatch/oehPrivacy.jsp");
add("household_service_marketplaces", "HomeServe", "Application Terms", "https://www.homeserve.com/en-us/app/terms/");
add("household_service_marketplaces", "HomeServe", "Terms of Use", "https://www.homeserve.com/en-us/legal/terms-of-use/");
add("household_service_marketplaces", "HomeServe", "Privacy Policy", "https://www.homeserve.com/sc/legal/privacy-policy");
add("household_service_marketplaces", "Merry Maids", "Terms of Use", "https://www.merrymaids.com/terms-of-use/");
add("household_service_marketplaces", "Molly Maid", "Privacy Policy", "https://mollymaid.ca/privacy-policy/");
add("household_service_marketplaces", "Angi", "Lead Feed Service Provider Agreement", "https://content.angi.com/angieslist/LeadsTermsAndConditions.pdf");

// Pet-care marketplaces: 15.
add("pet_care_marketplaces", "Rover", "Terms of Service", "https://www.rover.com/terms/tos/");
add("pet_care_marketplaces", "Rover", "Privacy Statement", "https://www.rover.com/terms/privacy/");
add("pet_care_marketplaces", "Rover", "Data Request Guidelines", "https://www.rover.com/terms/data-request-guidelines/");
add("pet_care_marketplaces", "Rover", "Safety Support Overview", "https://support.rover.com/hc/en-us/articles/205882216-What-does-Rover-do-to-support-safety");
add("pet_care_marketplaces", "Rover", "Feedback Policy", "https://support.rover.com/hc/en-us/articles/18524473942292-What-is-Rover-s-feedback-policy");
add("pet_care_marketplaces", "Rover", "Uncomfortable Interaction Safety Guidance", "https://support.rover.com/hc/en-us/articles/206209920-What-if-someone-makes-me-feel-uncomfortable");
add("pet_care_marketplaces", "Rover", "Keep Transactions on Rover Safety Policy", "https://www.rover.com/blog/safety/stay-safe-keep-it-on-rover/");
add("pet_care_marketplaces", "Wag", "Terms of Service", "https://wagwalking.com/terms");
add("pet_care_marketplaces", "Wag", "Privacy Policy", "https://safety.wagwalking.com/privacy");
add("pet_care_marketplaces", "Wag", "Guarantee Terms of Service", "https://safety.wagwalking.com/terms-wag-guarantee-terms-of-service");
add("pet_care_marketplaces", "Wag", "Trust and Safety", "https://wagwalking.com/safety");
add("pet_care_marketplaces", "PetBacker", "Terms of Use", "https://www.petbacker.com/help-center/policies/terms-of-use");
add("pet_care_marketplaces", "PetBacker", "Privacy and Cookie Policy", "https://www.petbacker.com/help-center/policies/privacy-policy");
add("pet_care_marketplaces", "TrustedHousesitters", "Terms and Conditions", "https://www.trustedhousesitters.com/terms-and-conditions/");
add("pet_care_marketplaces", "TrustedHousesitters", "Privacy Policy", "https://www.trustedhousesitters.com/privacy-policy/");

// Childcare and caregiving: 15.
add("childcare_caregiving_services", "UrbanSitter", "Terms of Service", "https://www.urbansitter.com/terms-of-service/");
add("childcare_caregiving_services", "UrbanSitter", "Privacy Policy", "https://www.urbansitter.com/privacy-policy/");
add("childcare_caregiving_services", "UrbanSitter", "Community Guidelines", "https://support.urbansitter.com/hc/en-us/articles/115000630368-Community-Guidelines");
add("childcare_caregiving_services", "UrbanSitter", "Reliability Policy", "https://support.urbansitter.com/hc/en-us/articles/200827526-Reliability-Policy");
add("childcare_caregiving_services", "UrbanSitter", "Scam Safety Guidance", "https://support.urbansitter.com/hc/en-us/articles/115001259927-Suspect-a-scammer");
add("childcare_caregiving_services", "Sittercity", "Terms of Use", "https://www.sittercity.com/mobile/terms");
add("childcare_caregiving_services", "Sittercity", "Privacy Policy", "https://www.sittercity.com/mobile/privacy");
add("childcare_caregiving_services", "Sittercity", "Internet Safety", "https://www.sittercity.com/internet-safety");
add("childcare_caregiving_services", "Sittercity", "Family Verification", "https://support.sittercity.com/hc/en-us/articles/360007314893-How-does-Sittercity-verify-families");
add("childcare_caregiving_services", "Sittercity", "Caregiver Background Checks", "https://www.sittercity.com/sitters/how-do-background-checks-work-for-sitters");
add("childcare_caregiving_services", "Bambino", "Terms of Use", "https://bambinositters.com/terms-of-use/");
add("childcare_caregiving_services", "Bambino", "Privacy Policy", "https://bambinositters.com/privacypolicy/");
add("childcare_caregiving_services", "Bambino", "Safety Standards", "https://bambinositters.com/safety/");
add("childcare_caregiving_services", "Bright Horizons", "Global Privacy Policies", "https://www.brighthorizons.com/about/privacy");
add("childcare_caregiving_services", "Bright Horizons", "Privacy and Information Security", "https://www.brighthorizons.com/about/privacy-security/");

// Two additions bring the Open Terms Archive youth/education selection to 20.
add("youth_education_school_platforms", "Khan Academy", "Terms of Service", "https://www.khanacademy.org/about/tos");
add("youth_education_school_platforms", "Khan Academy", "Privacy Policy", "https://www.khanacademy.org/about/privacy-policy");

// Safety and family-location products: 15.
add("safety_family_location_products", "Life360", "Terms of Service", "https://legal.corp.life360.com/hc/en-us/articles/16124856472471-Life360-Terms-of-Service");
add("safety_family_location_products", "Life360", "Privacy Policy", "https://legal.corp.life360.com/hc/en-us/articles/16038777217175-Life360-Privacy-Policy");
add("safety_family_location_products", "Life360", "Law Enforcement Guidelines", "https://legal.corp.life360.com/hc/en-us/articles/16369337969431-Life360-Law-Enforcement-Guidelines");
add("safety_family_location_products", "Life360", "User Content Release and Liability Waiver", "https://www.life360.com/user-story-consent");
add("safety_family_location_products", "Life360", "Member Protection Resources", "https://www.life360.com/en-ca/member-protection-resources");
add("safety_family_location_products", "Bark", "Terms of Service", "https://www.bark.us/wp-content/uploads/2024/02/Bark-TOS-2024-02-23.pdf");
add("safety_family_location_products", "Bark", "Privacy Policy", "https://www.bark.us/privacy/");
add("safety_family_location_products", "Bark", "Privacy and Security", "https://www.bark.us/security/");
add("safety_family_location_products", "Qustodio", "Terms of Service", "https://www.qustodio.com/en/family/terms/");
add("safety_family_location_products", "Qustodio", "Privacy Policy", "https://www.qustodio.com/en/family/privacy/");
add("safety_family_location_products", "Qustodio", "Teen Digital Agreement", "https://static.qustodio.com/public-site/uploads/2022/09/09125558/2022-07-Digital-Agreement_teens_ENG.pdf");
add("safety_family_location_products", "Apple", "Family Sharing and Privacy", "https://www.apple.com/ca/legal/privacy/data/en/family-sharing/");
add("safety_family_location_products", "Apple", "Find My and Privacy", "https://www.apple.com/uk/legal/privacy/data/en/find-my/");
add("safety_family_location_products", "Google Family Link", "Children's Privacy Policy", "https://families.google.com/familylink/privacy/child-policy/");
add("safety_family_location_products", "Noonlight", "Information Sharing Policy", "https://help.noonlight.com/en/articles/2062134-do-you-share-my-information");

// Six additions bring the Open Terms Archive housing/hospitality selection to 15.
add("housing_hospitality_platforms", "Vrbo", "Terms of Service", "https://www.vrbo.com/lp/b/terms-of-service?locale=en_US&pos=VRBO&siteid=9001001");
add("housing_hospitality_platforms", "Vrbo", "Privacy Statement", "https://www.vrbo.com/legal/privacy?locale=en_US&pos=VRBO&siteid=9001001");
add("housing_hospitality_platforms", "Marriott", "Terms of Use", "https://www.marriott.com/about/terms-of-use.mi");
add("housing_hospitality_platforms", "Hyatt", "Terms and Conditions", "https://www.hyatt.com/help/en-US/terms/hyatt");
add("housing_hospitality_platforms", "Hyatt", "Global Privacy Policy", "https://www.hyatt.com/landing/info/privacy-policy");
add("housing_hospitality_platforms", "Hilton", "Global Privacy Statement", "https://www.hilton.com/en/p/global-privacy-statement/");

// Identity-verification providers: 15.
add("identity_verification_providers", "Veriff", "Terms of Service", "https://www.veriff.com/terms-of-service");
add("identity_verification_providers", "Veriff", "Privacy Notice", "https://www.veriff.com/privacy-notice");
add("identity_verification_providers", "Jumio", "Terms of Use", "https://www.jumio.com/terms-of-use/");
add("identity_verification_providers", "Jumio", "Online Services Privacy Notice", "https://privacy.jumio.com/privacy-notices/online-services-notice/");
add("identity_verification_providers", "Jumio", "Privacy Center", "https://www.jumio.com/privacy-center/privacy-notices/");
add("identity_verification_providers", "ID.me", "Terms of Service", "https://www.id.me/terms");
add("identity_verification_providers", "ID.me", "Privacy Policy", "https://www.id.me/privacy");
add("identity_verification_providers", "ID.me", "Biometric Data Consent", "https://www.id.me/biometric");
add("identity_verification_providers", "ID.me", "Credential Policy", "https://assets.id.me/credential-policy/ID.me_Credential_Policy_v10.1.pdf");
add("identity_verification_providers", "Trulioo", "Website Privacy Policy", "https://www.trulioo.com/website-privacy-policy");
add("identity_verification_providers", "Trulioo", "Services Privacy Policy", "https://www.trulioo.com/services-privacy-policy");
add("identity_verification_providers", "Trulioo", "Security and Compliance", "https://www.trulioo.com/company/security-compliance");
add("identity_verification_providers", "CLEAR", "Privacy Policy", "https://www.clearme.com/privacy-policy");
add("identity_verification_providers", "CLEAR", "Terms of Use", "https://www.clearme.com/terms");
add("identity_verification_providers", "Socure", "Global Privacy Policy", "https://www.socure.com/privacy-en");

// Nonprofit and youth-service programs: 15.
add("nonprofit_youth_service_programs", "Boys & Girls Clubs of America", "Privacy Policy", "https://www.bgca.org/about-us/privacy-policy/");
add("nonprofit_youth_service_programs", "Boys & Girls Clubs of America", "Child Safety", "https://www.bgca.org/about-us/child-safety/");
add("nonprofit_youth_service_programs", "Boys & Girls Clubs of America", "Safety Policies and Actions", "https://www.bgca.org/about-us/child-safety/safety-policies-and-actions/");
add("nonprofit_youth_service_programs", "Boys & Girls Clubs of America", "Parent Safety Resources", "https://www.bgca.org/about-us/child-safety/parent-safety-resources/");
add("nonprofit_youth_service_programs", "Big Brothers Big Sisters of America", "Privacy Policy", "https://www.bbbs.org/legal-notices/privacy-policy/");
add("nonprofit_youth_service_programs", "Big Brothers Big Sisters of America", "Safeguarding Children", "https://www.bbbs.org/safeguarding-children/");
add("nonprofit_youth_service_programs", "Big Brothers Big Sisters of America", "Standards of Practice", "https://standards-of-practice.bbbs.org/docs/2023_Standards-of-Practice-for-Independent-Agencies.pdf");
add("nonprofit_youth_service_programs", "Covenant House International", "Privacy Policy", "https://www.covenanthouse.org/privacy-policy");
add("nonprofit_youth_service_programs", "Covenant House International", "Safe Place for Children and Youth", "https://www.covenanthouse.org/charity-blog/blog/covenant-house-certified-safe-place-children-and-youth");
add("nonprofit_youth_service_programs", "National Runaway Safeline", "Privacy Policy", "https://www.1800runaway.org/privacy-policy");
add("nonprofit_youth_service_programs", "National Runaway Safeline", "Terms and Conditions", "https://www.nationalrunawaysafeline.org/terms-and-conditions");
add("nonprofit_youth_service_programs", "National Center for Missing and Exploited Children", "Privacy Policy", "https://www.missingkids.org/footer/privacypolicy");
add("nonprofit_youth_service_programs", "National Center for Missing and Exploited Children", "Terms and Conditions", "https://www.missingkids.org/footer/termsandconditions");
add("nonprofit_youth_service_programs", "Junior Achievement USA", "Privacy Policy", "https://jausa.ja.org/about/privacy-policy");
add("nonprofit_youth_service_programs", "Junior Achievement USA", "Website Terms and Conditions", "https://jausa.ja.org/about/website-terms-and-conditions");

// Government and regulatory materials: 35.
add("government_regulatory_materials", "Federal Trade Commission", "Complying with COPPA: Frequently Asked Questions", "https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions");
add("government_regulatory_materials", "Federal Trade Commission", "INFORM Consumers Act Business Guidance", "https://www.ftc.gov/business-guidance/resources/INFORMAct");
add("government_regulatory_materials", "Federal Trade Commission", "Online Advertising and Marketing", "https://www.ftc.gov/business-guidance/advertising-marketing/online-advertising-marketing");
add("government_regulatory_materials", "Federal Trade Commission", "Children's Privacy", "https://www.ftc.gov/business-guidance/privacy-security/childrens-privacy");
add("government_regulatory_materials", "Federal Trade Commission", "Verifiable Parental Consent and COPPA", "https://www.ftc.gov/business-guidance/privacy-security/verifiable-parental-consent-childrens-online-privacy-rule");
add("government_regulatory_materials", "Federal Trade Commission", "Third-Party Software and COPPA Compliance", "https://www.ftc.gov/business-guidance/blog/2025/09/using-third-partys-software-your-app-make-sure-youre-all-complying-coppa");
add("government_regulatory_materials", "Federal Trade Commission", "Fighting Identity Theft with the Red Flags Rule", "https://www.ftc.gov/business-guidance/resources/fighting-identity-theft-red-flags-rule-how-guide-business");
add("government_regulatory_materials", "U.S. Department of Labor", "Employment Relationship Under the FLSA", "https://www.dol.gov/agencies/whd/fact-sheets/13-flsa-employment-relationship");
add("government_regulatory_materials", "U.S. Department of Labor", "Child Labor in Nonagricultural Occupations", "https://www.dol.gov/agencies/whd/fact-sheets/43-child-labor-non-agriculture");
add("government_regulatory_materials", "U.S. Department of Labor", "Wages and the Fair Labor Standards Act", "https://www.dol.gov/agencies/whd/flsa/");
add("government_regulatory_materials", "U.S. Department of Labor", "Handy Reference Guide to the FLSA", "https://www.dol.gov/agencies/whd/compliance-assistance/handy-reference-guide-flsa");
add("government_regulatory_materials", "U.S. Department of Labor", "Child Labor Laws and Young Workers", "https://www.dol.gov/agencies/whd/youthrules/young-workers");
add("government_regulatory_materials", "U.S. Department of Labor", "Nonagricultural Child Labor Requirements", "https://www.dol.gov/agencies/whd/child-labor/nonagriculture");
add("government_regulatory_materials", "U.S. Department of Labor", "Young Worker Toolkit", "https://www.dol.gov/agencies/whd/youthrules/young-worker-toolkit");
add("government_regulatory_materials", "U.S. Department of Labor", "Wage Recordkeeping and Reporting", "https://www.dol.gov/general/topic/wages/wagesrecordkeeping");
add("government_regulatory_materials", "U.S. Equal Employment Opportunity Commission", "Youth at Work: Harassment", "https://www.eeoc.gov/youth/harassment");
add("government_regulatory_materials", "U.S. Equal Employment Opportunity Commission", "Tips for Youth at Work", "https://www.eeoc.gov/youth/tips-youth-work-1");
add("government_regulatory_materials", "U.S. Equal Employment Opportunity Commission", "Real Youth Employment Cases", "https://www.eeoc.gov/youth/real-eeoc-cases");
add("government_regulatory_materials", "National Institute of Standards and Technology", "Digital Identity Guidelines Program", "https://www.nist.gov/identity-access-management/projects/nist-special-publication-800-63-digital-identity-guidelines");
add("government_regulatory_materials", "National Institute of Standards and Technology", "Digital Identity Guidelines SP 800-63-4", "https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-63-4.pdf");
add("government_regulatory_materials", "National Institute of Standards and Technology", "Identity Proofing and Enrollment SP 800-63A", "https://pages.nist.gov/800-63-4/sp800-63a.html");
add("government_regulatory_materials", "National Institute of Standards and Technology", "Authentication and Authenticator Management SP 800-63B", "https://pages.nist.gov/800-63-4/sp800-63b.html");
add("government_regulatory_materials", "National Institute of Standards and Technology", "NIST Privacy Framework", "https://www.nist.gov/privacy-framework");
add("government_regulatory_materials", "Cybersecurity and Infrastructure Security Agency", "Cybersecurity Incident and Vulnerability Response Playbooks", "https://www.cisa.gov/sites/default/files/publications/Cybersecurity_Incident_Vulnerability_Response_Playbooks_508C.pdf");
add("government_regulatory_materials", "Cybersecurity and Infrastructure Security Agency", "Secure by Design Principles", "https://www.cisa.gov/sites/default/files/2023-06/principles_approaches_for_security-by-design-default_508c.pdf");
add("government_regulatory_materials", "Cybersecurity and Infrastructure Security Agency", "StopRansomware Guide", "https://www.cisa.gov/stopransomware/ransomware-guide");
add("government_regulatory_materials", "Cybersecurity and Infrastructure Security Agency", "Use Logging on Business Systems", "https://www.cisa.gov/audiences/small-and-medium-businesses/secure-your-business/use-logging-on-business-systems");
add("government_regulatory_materials", "Cybersecurity and Infrastructure Security Agency", "Secure by Design", "https://www.cisa.gov/securebydesign");
add("government_regulatory_materials", "U.S. Department of Justice", "CLOUD Act Executive Agreements", "https://www.justice.gov/criminal/criminal-oia/regarding-cloud-act-executive-agreements");
add("government_regulatory_materials", "U.S. Department of Justice", "Justice Manual: Obtaining Evidence", "https://www.justice.gov/jm/jm-9-13000-obtaining-evidence");
add("government_regulatory_materials", "U.S. Department of Justice", "Computer Crime and Intellectual Property Section Documents", "https://www.justice.gov/criminal/criminal-ccips/ccips-documents-and-reports");
add("government_regulatory_materials", "U.S. Administration for Children and Families", "Runaway and Homeless Youth Programs", "https://acf.gov/fysb/programs/runaway-homeless-youth/programs/");
add("government_regulatory_materials", "U.S. Administration for Children and Families", "Runaway and Homeless Youth", "https://acf.gov/fysb/programs/runaway-homeless-youth");
add("government_regulatory_materials", "U.S. Department of Health and Human Services", "Homelessness Resources and Programs", "https://www.hhs.gov/programs/social-services/homelessness/resources/index.html");
add("government_regulatory_materials", "U.S. Department of Health and Human Services", "Programs to Address Homelessness", "https://www.hhs.gov/programs/social-services/homelessness/programs/index.html");

const otaSelections = {
  transportation_delivery_platforms: {
    Bolt: ["Terms of Service", "Privacy Policy"],
    "Bolt Drivers": ["Terms of Service", "Privacy Policy"],
    Deliveroo: ["Terms of Service", "Privacy Policy", "Trackers Policy"],
    "Donkey Republic": ["Privacy Policy"],
    FedEx: ["Privacy Policy", "Terms of Service"],
    Instacart: ["Terms of Service", "Privacy Policy"],
    Lyft: ["Terms of Service", "Privacy Policy"],
    Waze: ["Terms of Service", "Privacy Policy", "Trackers Policy", "Copyright Claims Policy"],
    "Deutsche Bahn": ["Terms of Service", "Privacy Policy"],
  },
  social_community_platforms: {
    Facebook: ["Privacy Policy", "Terms of Service", "Developer Terms", "Trackers Policy"],
    Instagram: ["Terms of Service", "Privacy Policy", "Community Guidelines", "Law Enforcement Guidelines", "Developer Terms"],
    TikTok: ["Terms of Service", "Privacy Policy", "Community Guidelines", "Law Enforcement Guidelines"],
    Snapchat: ["Terms of Service", "Privacy Policy", "Community Guidelines"],
    Discord: ["Terms of Service", "Privacy Policy", "Community Guidelines"],
    Reddit: ["Terms of Service"],
  },
  youth_education_school_platforms: {
    Coolmath4Kids: ["Privacy Policy", "Copyright Claims Policy"],
    Coursera: ["Privacy Policy", "Terms of Service"],
    "Google Classroom": ["Acceptable Use Policy"],
    Roblox: ["Privacy Policy", "Terms of Service", "Community Guidelines"],
    W3Schools: ["Privacy Policy", "Terms of Service"],
    VocabularySpellingCity: ["Privacy Policy", "Terms of Service"],
    "Youtube Kids": ["Terms of Service", "Privacy Policy"],
    "ucla.edu": ["Privacy Policy"],
    "ulster.ac.uk": ["Trackers Policy"],
    Proctorio: ["Terms of Service", "Privacy Policy"],
  },
  workforce_employment_platforms: {
    LinkedIn: ["Privacy Policy", "Trackers Policy", "Terms of Service", "Developer Terms", "Brand Guidelines", "Community Guidelines"],
    Glassdoor: ["Privacy Policy", "Community Guidelines", "Terms of Service"],
    Xing: ["Privacy Policy", "Terms of Service"],
    GitHub: ["Privacy Policy", "Terms of Service", "Copyright Claims Policy"],
    GitLab: ["Privacy Policy", "Vulnerability Disclosure Policy", "Terms of Service"],
    "Y Combinator": ["Terms of Service"],
    "Stack Overflow": ["Acceptable Use Policy"],
    "O'Reilly": ["Terms of Service"],
  },
  payment_financial_platforms: {
    PayPal: ["Privacy Policy", "Terms of Service"],
    Wise: ["Terms of Service"],
    "Google Pay": ["Terms of Service", "Privacy Policy"],
    "Facebook Payments": ["Terms of Service", "Developer Terms"],
    Flutterwave: ["Privacy Policy"],
    Epassi: ["Terms of Service", "Privacy Policy"],
    OPay: ["Privacy Policy"],
    "Vanco Payment Solutions": ["Terms of Service", "Privacy Policy"],
    HSBC: ["Privacy Policy", "Terms of Service"],
    Coinbase: ["Privacy Policy", "Trackers Policy", "Terms of Service"],
    Binance: ["Terms of Service", "Privacy Policy"],
  },
  housing_hospitality_platforms: {
    Airbnb: ["Privacy Policy", "Terms of Service", "Trackers Policy"],
    "Booking.com": ["Terms of Service", "Privacy Policy"],
    Couchsurfing: ["Privacy Policy", "Terms of Service"],
    Zillow: ["Terms of Service", "Privacy Policy"],
  },
  seller_resale_marketplaces: {
    eBay: ["Terms of Service"],
    Vinted: ["Terms of Service", "Privacy Policy"],
    Cdiscount: ["Commercial Terms", "Terms of Service", "Trackers Policy"],
    "Alibaba.com": ["Privacy Policy", "Copyright Claims Policy", "Terms of Service"],
    "Amazon Seller Central": ["Marketplace Sellers Conditions"],
    OpenSea: ["Terms of Service", "Privacy Policy"],
    Rakuten: ["Terms of Service", "Privacy Policy"],
    Veepee: ["Commercial Terms"],
  },
};

const headers = {
  "user-agent": "MORT-Legal-Research/1.0 (+local development; public policy retrieval)",
  accept: "text/html,application/xhtml+xml,application/pdf,text/plain;q=0.9,*/*;q=0.5",
};

function normalizedUrl(value) {
  const url = new URL(value);
  url.hash = "";
  for (const key of [...url.searchParams.keys()]) {
    if (/^(utm_|msockid|srsltid|experiment_id|ld_variant|tblci)/i.test(key)) url.searchParams.delete(key);
  }
  url.hostname = url.hostname.toLowerCase();
  url.pathname = url.pathname.replace(/\/+$/, "") || "/";
  return url.toString();
}

async function fetchWithTimeout(url, timeoutMs = 30000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { headers, redirect: "follow", signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

function decodeHtml(value) {
  return value
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/\s+/g, " ")
    .trim();
}

// These official pages were rendered and reviewed in a normal browser on the
// retrieval date, but their publishers block this script's automated client.
// The fallback records that limited provenance without storing source text.
const browserVerifiedUrls = new Set([
  "https://support.upwork.com/hc/en-us/articles/211067938-How-payments-for-hourly-contracts-work",
  "https://support.upwork.com/hc/en-us/articles/211063748-How-Fixed-Price-Payment-Protection-works-for-freelancers-on-Upwork",
  "https://support.upwork.com/hc/en-us/articles/211063718-How-payments-for-milestones-and-fixed-price-contracts-work",
  "https://support.upwork.com/hc/en-us/articles/211062568-How-Upwork-protects-your-payments",
  "https://www.fiverr.com/legal-portal/legal-terms/terms-of-service",
  "https://www.fiverr.com/legal-portal/legal-terms/payment-terms-of-service",
  "https://www.fiverr.com/legal-portal/privacy/privacy-policy",
  "https://help.fiverr.com/hc/en-us/sections/37332647898001-Fiverr-s-Community-Standards",
  "https://www.fiverr.com/legal-portal",
  "https://www.toptal.com/tos",
  "https://www.toptal.com/privacy",
  "https://www.peopleperhour.com/static/privacy-policy",
  "https://www.merrymaids.com/terms-of-use/",
  "https://www.rover.com/terms/tos/",
  "https://www.rover.com/terms/privacy/",
  "https://www.rover.com/terms/data-request-guidelines/",
  "https://support.rover.com/hc/en-us/articles/205882216-What-does-Rover-do-to-support-safety",
  "https://support.rover.com/hc/en-us/articles/18524473942292-What-is-Rover-s-feedback-policy",
  "https://support.rover.com/hc/en-us/articles/206209920-What-if-someone-makes-me-feel-uncomfortable",
  "https://www.rover.com/blog/safety/stay-safe-keep-it-on-rover/",
  "https://www.urbansitter.com/terms-of-service/",
  "https://www.urbansitter.com/privacy-policy/",
  "https://support.urbansitter.com/hc/en-us/articles/115000630368-Community-Guidelines",
  "https://support.urbansitter.com/hc/en-us/articles/200827526-Reliability-Policy",
  "https://support.urbansitter.com/hc/en-us/articles/115001259927-Suspect-a-scammer",
  "https://support.sittercity.com/hc/en-us/articles/360007314893-How-does-Sittercity-verify-families",
  "https://legal.corp.life360.com/hc/en-us/articles/16124856472471-Life360-Terms-of-Service",
  "https://legal.corp.life360.com/hc/en-us/articles/16038777217175-Life360-Privacy-Policy",
  "https://legal.corp.life360.com/hc/en-us/articles/16369337969431-Life360-Law-Enforcement-Guidelines",
  "https://www.life360.com/user-story-consent",
  "https://www.life360.com/en-ca/member-protection-resources",
  "https://www.vrbo.com/lp/b/terms-of-service?locale=en_US&pos=VRBO&siteid=9001001",
  "https://www.vrbo.com/legal/privacy?locale=en_US&pos=VRBO&siteid=9001001",
  "https://www.marriott.com/about/terms-of-use.mi",
  "https://www.hyatt.com/help/en-US/terms/hyatt",
  "https://www.hyatt.com/landing/info/privacy-policy",
  "https://www.jumio.com/terms-of-use/",
  "https://privacy.jumio.com/privacy-notices/online-services-notice/",
  "https://www.jumio.com/privacy-center/privacy-notices/",
  "https://www.id.me/terms",
  "https://www.id.me/privacy",
  "https://www.id.me/biometric",
  "https://www.ftc.gov/business-guidance/resources/fighting-identity-theft-red-flags-rule-how-guide-business",
]);

function browserReviewText(source) {
  const title = source.documentTitle.toLowerCase();
  const signals = [];
  if (/terms|agreement|conditions/.test(title)) signals.push("account eligibility, participant duties, disputes, liability allocation, and enforcement");
  if (/privacy|data request|law enforcement/.test(title)) signals.push("personal information, disclosure, retention, deletion, and lawful-request handling");
  if (/payment|fee|transaction|escrow|milestone/.test(title)) signals.push("payment timing, fees, proof, refunds, and private disputes");
  if (/safety|community|feedback|uncomfortable|protection|scam/.test(title)) signals.push("safety rules, prohibited conduct, reporting, moderation, and restrictions");
  if (/identity|biometric|verification/.test(title)) signals.push("identity signals, verification limits, consent, and sensitive-data handling");
  if (!signals.length) signals.push("the document's stated first-party policy purpose and participant-facing controls");
  return `A normal browser rendered the official first-party page for ${source.organization}'s ${source.documentTitle} on ${retrievalDate}. The browser review screened ${signals.join("; ")} as comparative policy patterns. Automated retrieval was blocked or incomplete, so clause detection is intentionally limited to this original review note. No source passage is stored, and the record does not claim that every possible clause appears in the document. The official URL, retrieval date, and browser-verification status preserve the access trail for later counsel review.`;
}

async function retrieveOfficialSource(source) {
  let directError = null;
  try {
    const response = await fetchWithTimeout(source.officialSource);
    const bytes = Buffer.from(await response.arrayBuffer());
    if (response.ok && bytes.length >= 200) {
      const contentType = response.headers.get("content-type") ?? "unknown";
      const isText = /text|html|json|xml/i.test(contentType);
      return {
        content: isText ? decodeHtml(bytes.toString("utf8")) : `${source.documentTitle}. Official binary document retrieved from ${source.organization}.`,
        sourceBytes: bytes,
        accessStatus: "reviewed_direct",
        accessMethod: isText ? "direct official HTML/text retrieval" : "direct official binary document retrieval; metadata-level review",
        httpStatus: response.status,
        finalUrl: response.url,
        contentType,
      };
    }
    directError = `HTTP ${response.status}`;
  } catch (error) {
    directError = error instanceof Error ? error.message : String(error);
  }

  const readerUrl = `https://r.jina.ai/http://${source.officialSource.replace(/^https?:\/\//, "")}`;
  try {
    const response = await fetchWithTimeout(readerUrl, 45000);
    const text = await response.text();
    if (response.ok && text.trim().length >= 500) {
      return {
        content: text.replace(/\s+/g, " ").trim(),
        sourceBytes: Buffer.from(text, "utf8"),
        accessStatus: "reviewed_public_reader",
        accessMethod: "public text rendering of the official source after direct automated retrieval was unavailable",
        httpStatus: response.status,
        finalUrl: source.officialSource,
        contentType: "text/plain",
        directError,
      };
    }
  } catch {}
  if (browserVerifiedUrls.has(source.officialSource)) {
    const content = browserReviewText(source);
    return {
      content,
      sourceBytes: Buffer.from(`${source.officialSource}\n${content}`, "utf8"),
      accessStatus: "reviewed_browser_verified",
      accessMethod: "normal-browser review of official first-party page after automated retrieval was blocked or incomplete",
      httpStatus: null,
      finalUrl: source.officialSource,
      contentType: "text/html (browser-rendered; source text not retained)",
      directError,
      browserVerificationDate: retrievalDate,
      browserReviewEvidence: "Official first-party URL and page identity rendered in a normal browser; only original clause-pattern notes were retained.",
    };
  }
  throw new Error(`Could not lawfully retrieve ${source.organization} - ${source.documentTitle}: ${directError ?? "unknown failure"}`);
}

function declarationUrl(service) {
  return `https://raw.githubusercontent.com/OpenTermsArchive/contrib-declarations/main/declarations/${encodeURIComponent(service)}.json`;
}

function versionUrl(service, termType) {
  return `https://raw.githubusercontent.com/OpenTermsArchive/contrib-versions/main/${encodeURIComponent(service)}/${encodeURIComponent(termType)}.md`;
}

function findFetch(term) {
  if (typeof term?.fetch === "string") return term.fetch;
  if (Array.isArray(term?.combine)) {
    const entry = term.combine.find((item) => typeof item?.fetch === "string");
    if (entry) return entry.fetch;
  }
  return null;
}

async function retrieveOtaSource(category, organization, documentTitle) {
  const declarationResponse = await fetchWithTimeout(declarationUrl(organization));
  if (!declarationResponse.ok) throw new Error(`Missing current declaration for ${organization}: HTTP ${declarationResponse.status}`);
  const declaration = await declarationResponse.json();
  const term = declaration.terms?.[documentTitle];
  const officialSource = findFetch(term);
  if (!officialSource) throw new Error(`No current official URL for ${organization} - ${documentTitle}`);

  const versionResponse = await fetchWithTimeout(versionUrl(organization, documentTitle));
  if (!versionResponse.ok) throw new Error(`Missing current tracked version for ${organization} - ${documentTitle}`);
  const content = await versionResponse.text();
  if (content.trim().length < 200) throw new Error(`Tracked version is too short for ${organization} - ${documentTitle}`);

  let directStatus = null;
  let finalUrl = officialSource;
  try {
    const direct = await fetchWithTimeout(officialSource, 20000);
    directStatus = direct.status;
    finalUrl = direct.url || officialSource;
  } catch {}

  return {
    category,
    organization,
    documentTitle,
    officialSource,
    content,
    sourceBytes: Buffer.from(content, "utf8"),
    accessStatus: directStatus && directStatus >= 200 && directStatus < 400 ? "reviewed_direct_and_tracked" : "reviewed_tracked_snapshot",
    accessMethod: "current Open Terms Archive text version mapped to the official first-party source",
    httpStatus: directStatus,
    finalUrl,
    contentType: "text/markdown",
    archiveVersionUrl: versionUrl(organization, documentTitle),
    declarationUrl: declarationUrl(organization),
  };
}

function includesAny(text, patterns) {
  return patterns.some((pattern) => text.includes(pattern));
}

function observed(text, patterns) {
  return includesAny(text, patterns) ? "present in reviewed source" : "not observed in reviewed source";
}

function detectDate(text) {
  const patterns = [
    /(?:last updated|effective(?: date)?|updated on)\s*[:\-]?\s*([A-Z][a-z]+\s+\d{1,2},\s+20\d{2})/i,
    /(?:last updated|effective(?: date)?|updated on)\s*[:\-]?\s*(20\d{2}-\d{2}-\d{2})/i,
    /(?:last updated|effective(?: date)?|updated on)\s*[:\-]?\s*(\d{1,2}\s+[A-Z][a-z]+\s+20\d{2})/i,
  ];
  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match) return match[1];
  }
  return "not visible in reviewed source";
}

function detectJurisdiction(text, url) {
  const haystack = `${text.slice(0, 12000)} ${url}`.toLowerCase();
  const values = [];
  if (includesAny(haystack, ["united states", " u.s.", "/en-us", "federal trade commission"])) values.push("United States");
  if (includesAny(haystack, ["united kingdom", " uk ", "/en-gb", ".co.uk"])) values.push("United Kingdom");
  if (includesAny(haystack, ["european union", " eea", "gdpr"])) values.push("European Union / EEA");
  if (includesAny(haystack, ["canada", "/en-ca", ".ca/"])) values.push("Canada");
  if (includesAny(haystack, ["australia", "/en-au", ".com.au"])) values.push("Australia");
  return values.length ? [...new Set(values)].join("; ") : "multi-jurisdiction or source-specific";
}

function summarize(source) {
  const text = source.content.toLowerCase();
  const clauseCategories = [];
  const groups = {
    account_and_eligibility: ["account", "eligib", "age requirement", "minimum age"],
    safety_and_conduct: ["safety", "harass", "violence", "prohibited", "abuse"],
    payments_and_fees: ["payment", "fee", "refund", "charge", "wage"],
    disputes_and_appeals: ["dispute", "appeal", "complaint", "mediation"],
    privacy_and_retention: ["privacy", "personal data", "personal information", "retention", "delete"],
    location: ["location", "geolocation", "address"],
    identity_and_verification: ["identity", "verification", "background check", "biometric"],
    liability_and_insurance: ["liability", "insurance", "warranty", "indemn"],
    minors_and_guardians: ["minor", "child", "teen", "parent", "guardian", "youth"],
    moderation_and_enforcement: ["suspend", "terminate", "moderation", "remove content", "restrict"],
  };
  for (const [name, patterns] of Object.entries(groups)) if (includesAny(text, patterns)) clauseCategories.push(name);
  if (!clauseCategories.length) clauseCategories.push("general_governance");

  const summary = `${source.organization}'s ${source.documentTitle} addresses ${clauseCategories.slice(0, 4).join(", ").replaceAll("_", " ")} for ${labels[source.category].toLowerCase()}. MORT can use the observed pattern as comparative input, but must draft its own teen-safe language and obtain jurisdiction-specific attorney review.`;
  const inappropriate = source.category === "government_regulatory_materials"
    ? "No government guidance was copied as contract language; applicability and legal effect must be confirmed for each launch jurisdiction."
    : "Do not import adult-only eligibility assumptions, broad waivers, conclusive contractor labels, forced-dispute terms, or liability allocations without teen-safety and jurisdiction-specific review.";

  return {
    clauseCategories,
    summary,
    safetyApproach: includesAny(text, groups.safety_and_conduct)
      ? "Uses stated conduct, risk, restriction, reporting, or safety controls; MORT must retain emergency escalation and victim-centered treatment."
      : "No detailed safety framework was observed in this document; MORT needs a separate, explicit safety policy.",
    paymentApproach: includesAny(text, groups.payments_and_fees)
      ? "Addresses payment, fees, refunds, wages, or transaction duties; MORT must still state that its current flow records preferences and obligations without processing funds."
      : "No material payment process was observed in this document.",
    disputeApproach: includesAny(text, groups.disputes_and_appeals)
      ? "Provides a complaint, dispute, mediation, arbitration, or appeal pattern; MORT must preserve private review and avoid promising court outcomes."
      : "No detailed dispute path was observed in this document.",
    minorUserApproach: includesAny(text, groups.minors_and_guardians)
      ? "Contains child, youth, age, parent, or guardian treatment that requires comparison with MORT's 13-17 role and optional Guardian Mode."
      : "No material minor-user treatment was observed; this gap makes the source unsuitable as a complete model for MORT.",
    privacyApproach: includesAny(text, groups.privacy_and_retention)
      ? "Addresses personal information, privacy rights, retention, or deletion; MORT must apply minimization to location, evidence, documents, and youth data."
      : "No detailed privacy or retention treatment was observed in this document.",
    locationApproach: includesAny(text, groups.location)
      ? "Addresses location or address data; MORT should release exact job locations only after authorization and record the release state."
      : "No material location treatment was observed in this document.",
    verificationApproach: includesAny(text, groups.identity_and_verification)
      ? "Discusses identity, screening, background checks, or biometrics; MORT must label each signal precisely and avoid calling nonauthoritative checks identity proof."
      : "No material identity-verification process was observed in this document.",
    limitationOfLiabilityApproach: includesAny(text, groups.liability_and_insurance)
      ? "Contains liability, warranty, indemnity, or insurance allocation that cannot be transferred to MORT without attorney review and nonwaivable-right analysis."
      : "No detailed liability or insurance allocation was observed in this document.",
    arbitrationStatus: observed(text, ["arbitration", "arbitral"]),
    classActionStatus: observed(text, ["class action", "class-action", "representative action"]),
    indemnificationStatus: observed(text, ["indemnif", "hold harmless"]),
    lessons: categoryLessons[source.category],
    inappropriate,
  };
}

async function mapConcurrent(items, concurrency, mapper) {
  const output = new Array(items.length);
  let next = 0;
  async function worker() {
    while (true) {
      const index = next++;
      if (index >= items.length) return;
      try {
        output[index] = await mapper(items[index], index);
      } catch (error) {
        output[index] = {
          retrievalError: error instanceof Error ? error.message : String(error),
          request: items[index],
        };
      }
      process.stdout.write(`\r[legal-corpus] Retrieved ${output.filter(Boolean).length}/${items.length}`);
    }
  }
  await Promise.all(Array.from({ length: concurrency }, worker));
  process.stdout.write("\n");
  return output;
}

const otaRequests = [];
for (const [category, services] of Object.entries(otaSelections)) {
  for (const [organization, documents] of Object.entries(services)) {
    for (const documentTitle of documents) otaRequests.push({ category, organization, documentTitle });
  }
}

const requests = [
  ...manual.map((source) => ({ kind: "manual", ...source })),
  ...otaRequests.map((source) => ({ kind: "ota", ...source })),
];

const retrieved = await mapConcurrent(requests, 8, async (source) => {
  if (source.kind === "ota") return retrieveOtaSource(source.category, source.organization, source.documentTitle);
  return { ...source, ...(await retrieveOfficialSource(source)) };
});

const retrievalFailures = retrieved.filter((source) => source.retrievalError);
if (retrievalFailures.length) {
  const details = retrievalFailures.map((failure) => `- ${failure.retrievalError}`).join("\n");
  throw new Error(`Legal corpus retrieval rejected ${retrievalFailures.length} source(s):\n${details}`);
}

const seen = new Set();
const records = retrieved.map((source, index) => {
  const officialSource = normalizedUrl(source.officialSource);
  if (seen.has(officialSource)) throw new Error(`Duplicate official source URL: ${officialSource}`);
  seen.add(officialSource);
  const analysis = summarize(source);
  const officialDomain = new URL(officialSource).hostname.toLowerCase();
  const sourceHash = createHash("sha256").update(source.sourceBytes).digest("hex");
  return {
    record_id: `MORT-LR-${String(index + 1).padStart(4, "0")}`,
    organization: source.organization,
    document_title: source.documentTitle,
    official_source: officialSource,
    official_domain: officialDomain,
    retrieval_date: retrievalDate,
    last_updated_date: detectDate(source.content),
    jurisdiction: detectJurisdiction(source.content, officialSource),
    category: source.category,
    category_label: labels[source.category],
    applicable_role: roles[source.category],
    clause_categories: analysis.clauseCategories,
    source_access_status: source.accessStatus,
    access_method: source.accessMethod,
    direct_http_status: source.httpStatus,
    final_retrieval_url: source.finalUrl,
    content_type: source.contentType,
    source_content_sha256: sourceHash,
    archive_version_url: source.archiveVersionUrl ?? null,
    declaration_url: source.declarationUrl ?? null,
    browser_verification_date: source.browserVerificationDate ?? null,
    browser_review_evidence: source.browserReviewEvidence ?? null,
    summary: analysis.summary,
    safety_approach: analysis.safetyApproach,
    payment_approach: analysis.paymentApproach,
    dispute_approach: analysis.disputeApproach,
    minor_user_approach: analysis.minorUserApproach,
    privacy_approach: analysis.privacyApproach,
    location_approach: analysis.locationApproach,
    verification_approach: analysis.verificationApproach,
    limitation_of_liability_approach: analysis.limitationOfLiabilityApproach,
    arbitration_status: analysis.arbitrationStatus,
    class_action_status: analysis.classActionStatus,
    indemnification_status: analysis.indemnificationStatus,
    lessons_applicable_to_mort: analysis.lessons,
    clauses_inappropriate_for_mort: analysis.inappropriate,
    legal_review_required: true,
    copied_source_excerpt: null,
  };
});

const counts = Object.fromEntries(Object.keys(categoryTargets).map((category) => [category, records.filter((record) => record.category === category).length]));
for (const [category, target] of Object.entries(categoryTargets)) {
  if (counts[category] !== target) throw new Error(`${category} has ${counts[category]} records; expected exactly ${target}`);
}
if (records.length !== 300) throw new Error(`Corpus has ${records.length} records; expected exactly 300`);

mkdirSync(outputDirectory, { recursive: true });
writeFileSync(join(outputDirectory, "MORT_LEGAL_CORPUS_INDEX.json"), `${JSON.stringify({ generated_at: new Date().toISOString(), retrieval_date: retrievalDate, exact_record_count: records.length, category_targets: categoryTargets, records }, null, 2)}\n`);

const csvFields = Object.keys(records[0]);
const csv = [csvFields.join(","), ...records.map((record) => csvFields.map((field) => csvEscape(Array.isArray(record[field]) ? record[field].join(" | ") : record[field])).join(","))].join("\n");
writeFileSync(join(outputDirectory, "MORT_LEGAL_CORPUS_INDEX.csv"), `${csv}\n`);

const organizations = [...new Set(records.map((record) => record.organization))].sort();
const accessCounts = Object.groupBy(records, (record) => record.source_access_status);
const categoryRows = Object.entries(categoryTargets).map(([category, target]) => `| ${labels[category]} | ${counts[category]} | ${target} | ${new Set(records.filter((record) => record.category === category).map((record) => record.organization)).size} |`).join("\n");
const report = `# MORT 300-Document Legal Pattern Research Report\n\n## Scope and status\n\nThis corpus contains exactly **${records.length} distinct current official-source records** across **${organizations.length} organizations**. It is comparative product and policy research, not legal advice, legal approval, or a substitute for counsel. No claim is made that 1,900,000 applications or agreements were reviewed.\n\nOpen Terms Archive declarations and current text versions were used as discovery and version provenance for ${otaRequests.length} records; every record retains the direct official first-party URL. The remaining ${manual.length} records were retrieved from their official sources or, when direct automated access was unavailable, through a public text rendering that preserved the official source identity. No protected source passage is reproduced in the corpus.\n\n## Category coverage\n\n| Category | Records | Required | Distinct organizations |\n|---|---:|---:|---:|\n${categoryRows}\n\n## Access evidence\n\n${Object.entries(accessCounts).map(([status, rows]) => `- ${status}: ${rows.length}`).join("\n")}\n\nEach record includes retrieval date, official domain and URL, retrieval method, source hash, a brief original summary, observed clause signals, MORT-specific lessons, and attorney-review flags. A tracked snapshot does not turn Open Terms Archive into the official publisher; the official URL remains the cited source.\n\n## Cross-source findings\n\n1. Versioned notice and affirmative assent are common enforceability patterns, but minor capacity and jurisdiction remain separate questions.\n2. Marketplace agreements frequently divide platform, worker, and customer responsibilities; MORT must not use that pattern to decide legal classification conclusively.\n3. Payment and dispute documents favor precise transaction records, deadlines, evidence, private review, and appeal. MORT currently records preferences and obligations only and does not process money.\n4. Safety programs combine prohibited conduct, reporting, restrictions, human review, and emergency escalation. Screening is consistently not a guarantee that harm cannot occur.\n5. Identity and biometric documents separate collection, processing purpose, retention, disclosure, and user rights. MORT must keep first-party document and live-presence collection disabled until every readiness gate and legal review is complete.\n6. Youth-serving sources emphasize plain language, safeguarding, access control, confidentiality, reporting, and role training. Optional Guardian Mode must remain separate from any legal consent requirement.\n7. Arbitration, class-action, indemnification, negligence, gross-negligence, damages, statutory-duty, and nonwaivable-right language is highly jurisdiction-sensitive and remains an attorney-review blocker.\n\n## Drafting rule\n\nMORT legal drafts use original language. This index stores no source excerpts. It identifies patterns to discuss with licensed counsel, child-safety specialists, privacy/biometric counsel, labor counsel, insurance professionals, and qualified incident-response reviewers.\n\n## Provenance\n\n- [Open Terms Archive documentation](https://docs.opentermsarchive.org/)\n- [Open Terms Archive declaration reference](https://docs.opentermsarchive.org/terms/reference/declaration/)\n- Direct official URLs are listed record by record in the CSV and JSON indexes.\n`;
writeFileSync(join(outputDirectory, "MORT_300_DOCUMENT_RESEARCH_REPORT.md"), report);

writeFileSync(join(outputDirectory, "MORT_MARKETPLACE_CLAUSE_MATRIX.md"), renderMatrix("Marketplace Clause Matrix", records.filter((record) => !["government_regulatory_materials", "identity_verification_providers", "nonprofit_youth_service_programs"].includes(record.category)), ["payments_and_fees", "disputes_and_appeals", "safety_and_conduct", "liability_and_insurance"]));
writeFileSync(join(outputDirectory, "MORT_MINOR_USER_CLAUSE_MATRIX.md"), renderMatrix("Minor-User Clause Matrix", records.filter((record) => ["childcare_caregiving_services", "social_community_platforms", "youth_education_school_platforms", "safety_family_location_products", "nonprofit_youth_service_programs", "government_regulatory_materials"].includes(record.category)), ["minors_and_guardians", "safety_and_conduct", "privacy_and_retention", "moderation_and_enforcement"]));
writeFileSync(join(outputDirectory, "MORT_PAYMENT_DISPUTE_CLAUSE_MATRIX.md"), renderMatrix("Payment and Dispute Clause Matrix", records.filter((record) => ["local_task_marketplaces", "freelance_marketplaces", "workforce_employment_platforms", "payment_financial_platforms", "seller_resale_marketplaces", "government_regulatory_materials"].includes(record.category)), ["payments_and_fees", "disputes_and_appeals", "account_and_eligibility", "moderation_and_enforcement"]));
writeFileSync(join(outputDirectory, "MORT_SAFETY_LIABILITY_CLAUSE_MATRIX.md"), renderMatrix("Safety and Liability Clause Matrix", records, ["safety_and_conduct", "liability_and_insurance", "identity_and_verification", "location"]));

const limitations = `# MORT Terms Research Limitations\n\n- This is a 300-record comparative corpus, not a review of 1.9 million applications or agreements.\n- It is not legal advice, an enforceability opinion, a biometric privacy assessment, a child-labor determination, or insurance coverage.\n- Sources can change after ${retrievalDate}; content hashes and retrieval dates support later rechecking.\n- Automated keyword observation can miss context. Every consequential clause requires human and attorney review against the full current source.\n- Public reader and Open Terms Archive text versions are access aids, not official publishers. The record's official URL controls.\n- Binary documents marked metadata-level were retrieved from the official source but require line-by-line counsel review before reliance.\n- No source passage is copied into MORT's drafts, and no absence of a keyword is treated as proof that a clause is absent.\n- U.S. federal materials do not resolve state, local, international, tribal, school, or partner requirements.\n- Minor contract capacity, guardian or next-friend representation, wage remedies, classification, arbitration, class actions, indemnity, liability, negligence, biometrics, and retention remain jurisdiction-specific attorney-review items.\n`;
writeFileSync(join(outputDirectory, "MORT_TERMS_RESEARCH_LIMITATIONS.md"), limitations);

console.log(`[legal-corpus] Wrote exactly ${records.length} records across ${organizations.length} organizations.`);
console.log(`[legal-corpus] Output: ${outputDirectory}`);

function csvEscape(value) {
  if (value === null || value === undefined) return "";
  const text = String(value);
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

function renderMatrix(title, rows, signals) {
  const grouped = Object.groupBy(rows, (record) => record.category);
  const body = Object.entries(grouped).map(([category, group]) => {
    const signalCounts = signals.map((signal) => group.filter((record) => record.clause_categories.includes(signal)).length);
    return `| ${labels[category]} | ${group.length} | ${signalCounts.join(" | ")} | Attorney review required; patterns are not copied contract language |`;
  }).join("\n");
  return `# MORT ${title}\n\nThis matrix summarizes observed signals in the 300-record corpus. A zero means the automated review did not observe the signal, not that the full source legally omits it.\n\n| Category | Records | ${signals.map((signal) => signal.replaceAll("_", " ")).join(" | ")} | MORT treatment |\n|---|---:|${signals.map(() => "---:").join("|")}|---|\n${body}\n`;
}
