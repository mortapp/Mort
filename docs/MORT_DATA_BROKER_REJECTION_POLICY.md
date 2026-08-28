# MORT Data Broker Rejection Policy

MORT does not use random people-search sites, commercial address-history services, phone-owner scraping, social-profile inference, relatives/associates lookup, data-broker dossiers, school-roster scraping, juvenile-record scraping, or public social profiles as identity verification.

MORT will not use public data to locate a residence, publish a residence, infer legal identity from social media, or accuse a person of a crime. A source must not be accepted merely because it is reachable without authentication.

## Enforcement

- business requests must use an allowlisted official host and HTTPS
- source category and jurisdiction are server checked
- official-source automation defaults to disabled
- reviewer access is role-limited and audited
- public badge RPCs omit residence, school name by default, and contact values
- QA asserts a people-search source cannot create a trust signal
- policy metadata reports `people_search_used = false`

Any proposed exception requires written legal/privacy and teen-safety approval, a necessity assessment, source licensing review, correction/appeal procedure, retention schedule, and a new server policy. There is no current exception.
