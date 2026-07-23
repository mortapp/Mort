# Email Evidence Fallback Runbook

The app may open an email draft to `mortapp.help@gmail.com` containing a MORT case number and user-entered summary.

- Warn users not to email passwords, PINs, payment/bank data, SSNs, government IDs, or private evidence.
- Email submission does not mark a case received, linked, or resolved.
- Staff must verify the sender and case authorization before copying any safe factual text into support records.
- Do not import attachments automatically. The inbound synchronization adapter is disabled.
- Direct evidence to the approved private upload flow whenever available.
- Delete misdirected sensitive material according to the approved incident and retention policy.
