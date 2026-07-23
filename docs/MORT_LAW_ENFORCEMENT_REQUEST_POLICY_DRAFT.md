# MORT Law Enforcement Request Policy Draft

Status: legal-process preparation only. This document is not legal approval and no employee may disclose user data from it without counsel-approved authority and training.

## Intake

Requests enter a dedicated channel controlled by the legal-request reviewer role. Record agency, request reference, request type, received time, deadline, emergency claim, requested scope, requester contact, and the MORT incident/account references without copying sensitive evidence into an ordinary support ticket.

## Validation

1. Independently validate the agency and requester using official contact information.
2. Confirm jurisdiction, signature, date, legal authority, target identifiers, data categories, time range, return method, and nondisclosure demand.
3. Reject or narrow requests that are informal, overbroad, technically impossible, directed to the wrong entity, or unsupported by the required process.
4. Escalate foreign requests, school requests, civil subpoenas, preservation requests, and emergency requests to counsel.

## Scope And Production

Search only the validated identifiers and date range. Separate subscriber/account records, content, location, identity evidence, incident evidence, and deleted/expired data because different process may apply. Produce the minimum approved scope through a secure transfer. Never provide service-role keys, database access, unrelated users, internal detection logic, or unrestricted bucket access.

## Preservation

A valid preservation request may create a bounded `incident_preservation_orders` record with legal basis, scope, start, expiration, reviewer, and audit event. Counsel must validate the applicable duration and extension rules. Preservation does not itself authorize disclosure.

## Notice

Apply the counsel-approved user-notice policy, considering lawful nondisclosure, emergency safety, investigation integrity, and delayed-notice rules. Record why notice was sent, delayed, or prohibited and schedule reevaluation where allowed.

## Audit

Use `incident_law_enforcement_requests`, restricted timeline events, evidence-access grants, and private-data access logs. Record validation, legal review, scope decision, query/export operator, hash/manifest, transfer method, recipient, time, and disposition. Do not store request credentials or raw evidence in mobile clients.

## Primary Legal Starting Points

- Current U.S. Code section 2702: https://www.govinfo.gov/link/uscode/18/2702
- DOJ Stored Communications Act overview: https://www.justice.gov/jm/jm-9-13000-obtaining-evidence
- DOJ preservation-process discussion: https://www.justice.gov/criminal/criminal-oia/cloud-act-agreement-between-governments-us-united-kingdom-great-britain-and-northern

Counsel must review current law, MORT's provider classification, and each request. These links are not a disclosure authorization.
