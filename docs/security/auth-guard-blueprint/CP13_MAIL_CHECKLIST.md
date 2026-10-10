# Owner-run external mail checklist — CP13

Status: BLOCKED pending staging and a separate approved test sender. Messages sent: 0. Never use production SMTP credentials.

Approved recipient: slugterria@icloud.com only. Maximum20 total, counted before each send. Use a short synthetic test subject; do not capture a real code or link in screenshots/logs.

For each owner-authorized staging message record: sent ordinal/time, arrived count/time, inbox or spam placement, inbox preview, lock-screen preview, whether either reveals credential material, link opens fixed HTTPS confirmation/recovery flow, fragment survives the mail client handoff and is cleared immediately by the page, loading alone consumes nothing, human Continue succeeds, repeated/expired/wrong link fails. Copy SPF/DKIM/DMARC result labels exactly as shown in headers; never infer delivery/authentication from SMTP acceptance. Redact addresses, message IDs, tokens and private routing headers from shared evidence.

No sender/domain/DNS/provider changes are authorized by this checklist. Owner feedback and staging approval remain required.
