// MORT Privacy Policy.
#let blue = rgb("1687B7")
#let head-font = ("Noto Sans", "DejaVu Sans")

#set document(title: "MORT Privacy Policy", author: "MORT")
#set page(
  paper: "us-letter",
  margin: (top: 1.7cm, bottom: 1.7cm, x: 2.0cm),
  numbering: "1",
  footer: context {
    set text(font: head-font, size: 8pt, fill: luma(110))
    grid(
      columns: (1fr, auto),
      [MORT Privacy Policy · Effective October 2026],
      [Page #counter(page).display() of #counter(page).final().first()],
    )
  },
)
#set text(font: head-font, size: 9.4pt, lang: "en")
#set par(leading: 0.9em, spacing: 0.8em)
#set heading(numbering: "1.", outlined: true)
#show heading.where(level: 1): set text(fill: blue, size: 13pt)
#show heading.where(level: 1): set block(above: 1.3em, below: 0.65em)
#show heading.where(level: 2): set text(fill: blue, size: 10.5pt)
#show heading.where(level: 2): set block(above: 1.3em, below: 0.65em)

#let callout(body) = block(
  width: 100%,
  inset: 11pt,
  fill: rgb("EAF4FA"),
  stroke: (left: 3pt + blue),
  radius: 3pt,
)[#body]

#align(center)[
  #text(size: 25pt, weight: "bold", fill: blue)[MORT] \
  #text(size: 19pt, weight: "bold")[Privacy Policy] \
  #text(fill: luma(80))[How MORT collects, uses, and protects information]
]
#v(1em)
#text(size: 9pt)[Effective date: October 2026 · Applies to the MORT Platform]
#v(1.2em)
#callout[*Privacy at a glance.* MORT collects and uses information to operate the marketplace, support payments and communications, protect users, and comply with law. MORT does not sell the personal information of Youth Workers or use it for targeted advertising. This Policy does not limit any privacy right or protection that applicable law gives you.]

= Overview

MORT operates a marketplace platform connecting Posters, Youth Workers ages 13–17, Guardians, and other local users. This Privacy Policy explains what information MORT may collect, how it is used, when it is shared, and the choices available to users and Guardians.

This Policy should be read together with MORT’s Terms of Service, Community Guidelines, and Safety Rules. If a separate notice applies to a particular feature, that notice controls for that feature.

= Information MORT collects

== Information users provide

MORT may collect account details such as name, email address, phone number, date of birth or age range, profile photo, location preferences, and account credentials. Guardians may provide consent records, relationship information, and contact details. Posters may provide business information, Task descriptions, addresses, schedules, and payment instructions.

Users may also provide messages, reports, ratings, reviews, support requests, identity documents, emergency contacts, payout details, tax information, and other content submitted through the Platform.

== Information collected automatically

MORT may collect device and usage information such as IP address, browser or device type, operating system, approximate location, timestamps, pages or features used, crash logs, check-in events, and security signals. Location features may require separate permission and may be disabled by the user or Guardian.

== Information from others

MORT may receive information from Guardians, Posters, Youth Workers, payment providers, identity or age-verification vendors, background-screening vendors where permitted, analytics providers, safety-reporting sources, and public or government sources.

== Children under 13

The Platform is not for children under 13, and MORT does not knowingly collect personal information from them. If MORT learns that it has collected personal information from a child under 13, it will close the account and delete the information promptly, except where the law requires MORT to keep it. A parent or Guardian who believes a child under 13 has an account can report it through the MORT Support Center.

= How MORT uses information

MORT may use information to create and administer accounts; verify age, consent, identity, or payment eligibility; match users to Tasks; facilitate communications and payouts; provide check-ins and safety features; prevent fraud, abuse, and prohibited conduct; respond to reports; improve products; maintain records; comply with law; and protect the rights, safety, and security of users, MORT, and the public.

MORT may use aggregated or de-identified information for analytics, product development, and business planning when it is not reasonably used to identify a person.

= Youth and Guardian privacy

MORT designs Youth Worker accounts with data minimization and age-appropriate defaults. Guardians may receive available account, Task-status, check-in, suspension, and payout information through designated controls. Message content may be subject to automated safety filtering, moderation, or disclosure for safety, abuse prevention, legal process, or platform integrity.

MORT does not sell the personal information of Youth Workers, does not share it for cross-context behavioral advertising, and does not use it to show targeted advertising to Youth Workers.

A Guardian may request account suspension, access, correction, or deletion, subject to identity verification and legal or operational retention requirements. MORT maintains procedures for handling requests involving minors and does not disclose a minor’s information to an unauthorized person except as described in this Policy or as permitted by law.

= Sharing and disclosure

MORT may share information with service providers that support hosting, communications, identity or age checks, payments, fraud prevention, analytics, customer support, safety operations, and legal compliance. Providers receive only information reasonably necessary for their services and are required to maintain appropriate confidentiality and security protections.

MORT may share information with other users when necessary to operate a Task, such as a name, profile, Task details, approximate location, check-in status, or contact method enabled by the feature. MORT limits the personal information about Youth Workers that is visible to other users.

MORT may disclose information to law enforcement, regulators, courts, emergency responders, or other parties when required by law, legal process, or a good-faith belief that disclosure is necessary to prevent serious harm, fraud, abuse, or unlawful activity. MORT may also disclose information in connection with a merger, acquisition, financing, restructuring, or sale of assets.

= Payments and third-party services

Payments are processed through Stripe Connect or another authorized provider. Payment providers may collect and process financial, identity, tax, and transaction information under their own notices and terms. MORT does not control third-party privacy practices and users should review those notices directly.

MORT may use cookies, local storage, analytics tools, and similar technologies. Users may be able to limit some technologies through device or browser settings, although certain Platform functions may not work correctly without them.

= Security and retention

MORT uses administrative, technical, and organizational safeguards appropriate to the nature of the information, such as access controls, encryption in transit where supported, logging, least-privilege access, vendor review, and incident-response procedures. No system is completely secure.

MORT retains information for as long as reasonably necessary for the purposes described in this Policy, including account operation, safety, fraud prevention, payments, tax and accounting, dispute resolution, legal compliance, and enforcement. MORT applies retention periods based on data category, operational need, safety requirements, payment and tax obligations, dispute resolution, and applicable law.

= Your choices and rights

Depending on location and applicable law, users may request access, correction, deletion, portability, restriction, or information about processing. Users may withdraw certain consents, disable optional location features, manage communications, or close an account. Some information cannot be deleted immediately when retention is required by law, payment rules, safety needs, or a pending dispute.

Requests may be submitted through the MORT Support Center. MORT may verify identity and authority before completing a request, will respond within the time that applicable law requires, and will not retaliate against anyone for making a request. Users may have the right to appeal a denial or contact a privacy regulator.

= Changes and contact

MORT may update this Policy as the Platform, law, or data practices change. MORT will post the updated version and revise the effective date. Material changes will be communicated through an appropriate notice and, where required, renewed consent.

Privacy requests may be submitted through the MORT Support Center in the Platform under *Privacy & Data Requests*. MORT may verify identity and authority before completing a request.
