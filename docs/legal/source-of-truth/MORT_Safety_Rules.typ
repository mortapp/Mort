// MORT Safety Rules.
#let blue = rgb("1687B7")
#let green = rgb("2CA66F")
#let head-font = ("Noto Sans", "DejaVu Sans")

#set document(title: "MORT Safety Rules", author: "MORT")
#set page(
  paper: "us-letter",
  margin: (top: 1.5cm, bottom: 1.5cm, x: 2.0cm),
  numbering: "1",
  footer: context {
    set text(font: head-font, size: 8pt, fill: luma(110))
    grid(
      columns: (1fr, auto),
      [MORT Safety Rules · Effective October 2026],
      [Page #counter(page).display() of #counter(page).final().first()],
    )
  },
)
#set text(font: head-font, size: 9.4pt, lang: "en")
#set par(leading: 0.9em, spacing: 0.8em)
#set heading(numbering: "1.", outlined: true)
#show heading.where(level: 1): set text(fill: blue, size: 13pt)
#show heading.where(level: 1): set block(above: 1.1em, below: 0.6em)

#let callout(body) = block(
  width: 100%,
  inset: 11pt,
  fill: rgb("EEF8F1"),
  stroke: (left: 3pt + green),
  radius: 3pt,
)[#body]

#align(center)[
  #text(size: 25pt, weight: "bold", fill: blue)[MORT] \
  #text(size: 19pt, weight: "bold")[Safety Rules] \
  #text(fill: luma(80))[Practical safeguards for local Tasks involving Youth Workers]
]
#v(1em)
#text(size: 9pt)[Effective date: October 2026]
#v(1.2em)
#callout[*Safety first.* These Rules are a safety framework, not a guarantee of safety and not a substitute for emergency services, professional supervision, or applicable law.]

= Safety comes first

MORT provides software tools and marketplace rules to reduce risk. MORT does not control every Task, person, location, vehicle, animal, tool, or event. Posters, Youth Workers, and Guardians must make independent safety decisions and stop when conditions are unsafe.

For immediate danger, call emergency services (911 in the United States) or contact the appropriate public authority. Do not wait for an in-app response.

= Before a Task

Posters must provide a complete and truthful description, including location type, expected work, tools, materials, animals, stairs, weather exposure, supervision, approximate duration, and any known hazards. Posters must not hide a condition that could affect a Youth Worker’s decision to accept the Task.

Youth Workers should review the description with a Guardian, confirm the location and timing, understand the work, and accept only a Task that is lawful, age-appropriate, and within their ability. Guardians should confirm consent, discuss transportation and check-in expectations, and use available account controls.

A Task at a private residence may begin only after a Guardian approves that specific Task through the Platform. For work inside a residence, a second adult other than the Poster must be present and available throughout the Task. Do not require a Youth Worker to be alone with you in a vehicle or a secluded place.

Users should keep communication and check-ins within MORT’s available tools. Avoid sharing unnecessary personal information. Do not arrange secret meetings or ask a Youth Worker to bypass a Guardian, identity check, PIN, or safety control.

= At the Task location

Meet only at the agreed location and follow the agreed scope. A Youth Worker may stop, leave, or request help at any time. Posters must not change the Task into a more hazardous or materially different activity without a new, informed agreement and any required Platform approval.

Do not operate machinery, vehicles, power tools, chemicals, ladders, roofs, or other equipment unless the activity is expressly permitted, lawful, age-appropriate, and safely supervised where required. Do not enter an isolated, locked, restricted, or visibly unsafe area. Do not handle weapons, illegal drugs, dangerous substances, aggressive animals, or exposed electrical systems.

Do not transport a Youth Worker in a private vehicle unless the arrangement is lawful, disclosed, consented to, and supported by MORT’s applicable controls. Youth Workers may not drive or perform motor-vehicle delivery as part of a Task unless expressly permitted by law and Platform policy.

= Prohibited Task categories

#block(breakable: false)[#table(
  columns: (1.2fr, 2fr, 2.1fr),
  inset: 5pt,
  stroke: 0.35pt + luma(195),
  fill: (_, y) => if y == 0 { rgb("173A52") } else if calc.odd(y) { luma(248) } else { white },
  table.header(
    text(fill: white, weight: "bold")[Area],
    text(fill: white, weight: "bold")[Examples generally suitable only when safe and permitted],
    text(fill: white, weight: "bold")[Do not post or perform],
  ),
  [Yard & outdoor], [Raking, watering, weeding, push-mower work within applicable age limits, or other light manual work.], [Ride-on mowers, chainsaws, power cutters, tree climbing, roofs, or work above six feet.],
  [Property & home], [Organizing, surface cleaning, light packing, or paint preparation with permitted materials.], [Roofing, scaffolding, demolition, hazardous chemicals, exposed wiring, or unsafe premises.],
  [Animal care], [Domestic pet walking, feeding, or basic yard cleanup.], [Aggressive or exotic animals, livestock without appropriate supervision, or licensed veterinary tasks.],
  [Business & events], [Flyers, tutoring, inventory sorting, or light event setup.], [Heavy machinery, commercial transport, alcohol or tobacco service areas, or crowd-control duties.],
  [Transport], [Local errands on foot, bicycle, or public transit where lawful and safe.], [Motor-vehicle driving, delivery, or any task requiring an unheld license.],
)]

This list is illustrative, not exhaustive. State, federal, and local requirements may impose stricter limits based on age, hours, equipment, supervision, and industry.

= Check-ins and incident response

When a check-in or PIN feature is available, use it as instructed. A check-in confirms an event in the Platform; it does not prove that a location is safe or that a person is acting lawfully. Do not share a PIN with an unauthorized person.

If a Youth Worker feels unsafe: stop the Task, move to a safer public location if possible, contact a Guardian or trusted adult, use emergency services for immediate danger, and report the incident to MORT when safe. If an injury occurs, seek medical care and preserve relevant information.

Posters must report accidents, threats, suspected exploitation, missing check-ins, or material safety changes promptly. MORT may suspend a Task or account while reviewing a report.

= Privacy and dignity

Do not photograph, record, or publish a Youth Worker without a legitimate reason, appropriate notice, and any consent required by law. Never publish a home address, phone number, school, real-time location, identity document, or private message. Safety evidence should be shared only with MORT, a Guardian, emergency responders, or another appropriate authority.

= MORT’s role and limits

MORT may provide verification, messaging controls, reports, location features, check-ins, moderation, and educational prompts. These are risk-reduction measures only. MORT does not guarantee identity accuracy, task-site safety, lawful conduct, non-negligence, response time, or a particular outcome.

Users remain responsible for their own decisions and conduct. Nothing in these Rules limits rights or duties that applicable law does not allow MORT to limit.

= Contact and review

Safety reports may be submitted through the in-app *Report* function or the MORT Support Center. For immediate danger, call emergency services or contact the appropriate public authority; do not wait for an in-app response. MORT may update these Rules as Task categories, Platform features, or applicable requirements change.
