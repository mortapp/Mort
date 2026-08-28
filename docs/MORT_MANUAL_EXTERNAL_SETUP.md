# MORT Manual External Setup

The following actions require account owners or qualified reviewers and were not completed in this environment.

1. Stripe: activate the business account, complete owner verification, approve Connect capabilities, configure test then live secrets/webhook, set allowed redirect origins, configure negative-balance and dispute operations, and run provider end-to-end tests.
2. OpenAI: create the production project, approve data handling, set hard daily/monthly budgets and alerts, set the Edge secret, enable server controls, and rerun AI abuse/cost QA.
3. Apple: enroll, configure signing/provisioning, build in current Xcode on macOS, review privacy manifests, archive, upload to TestFlight, install on an iPhone, and execute the critical-device matrix.
4. Google Play: upload the AAB to a closed track, verify app signing, Data Safety, target audience, child-safety contact, tester access, Billing products, and pre-launch reports.
5. Legal/compliance: obtain written legal, tax/payment, privacy, youth labor, child/minor safety, and store-policy approval.
6. Operations: configure production monitoring, error and cost alerts, on-call owners, support staffing, emergency contacts, incident/breach exercises, backup schedule, and restore drill.
7. Domain/email: verify production legal/support domains, SPF/DKIM/DMARC, monitored support mailbox, and any future inbound-email adapter.

Do not enable public marketplace, real ID collection, live money movement, external AI, or real-user launch until these checks have dated evidence.
