# MORT Business Registry Verification

## Implemented workflow

An adult/business account may request a manual registry match using legal business name, jurisdiction, registration number, optional entity type, and an HTTPS URL whose host and jurisdiction appear in `official_source_allowlist`. The server rejects non-allowlisted sources and explicitly rejects people-search/data-broker use.

For Indiana, the allowlist contains the official INBiz and Indiana Secretary of State business-search hosts. Automation is disabled. A reviewer must inspect the official source, record matched status, confidence, snapshot time, expiry/recheck date, mismatch reason, access reason, and case ID.

## Meaning

Business registration matching confirms that a public business record exists. It does not prove the account holder owns the business or is authorized to represent it. `business_representative_claims` records an attested relationship separately and remains `pending_future_verification` until an approved identity/authority workflow exists.

No home address, owner address, or sensitive officer data is exposed publicly. Fragile HTML scraping is not used. Appeals are supported, but an appeal never changes trust automatically.

Official Indiana search: [INBiz](https://inbiz.in.gov/BOS/PublicSearch/Search)
