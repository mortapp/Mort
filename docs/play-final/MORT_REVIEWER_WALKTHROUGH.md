# MORT Reviewer Walkthrough 0.9.6

## Enter Review Mode

Tap **Sign in**, enter `play-review@mortapp.test`, then tap **Continue as Play Reviewer**. The password, Google, account creation, and recovery controls disappear only for that exact ASCII lowercase identifier. Similar addresses continue through normal password authentication.

The banner must always say **Google Play Review Mode**, **Synthetic demonstration data**, and **No real financial or administrative actions**.

## Role Journeys

- **Teen:** complete the synthetic profile, browse/filter jobs, apply, open the accepted job, enter START PIN `123456`, complete the checklist, attach the generated local proof card, request completion, enter COMPLETION PIN `654321`, advance the synthetic payment status, then review messages, dispute, support, Safety Ping, Guardian Mode, notifications, settings, and deletion explanation.
- **Adult:** review the synthetic business/verification/payment-method states, post the local job, review and accept Jordan, schedule work, display both demo PINs, review scope/completion, and inspect cancellation, partial compensation, receipts, messages, disputes, support, notifications, and settings.
- **Guardian:** review optional onboarding, teen-link request, linked summary, safety notifications, payout/dispute assistance, support, preferences, and unlinking.
- **Support:** review the synthetic queue and safety-critical case, messages, generated attachments, escalation, status changes, resolution, and reopening.
- **Admin:** review simulated support/dispute queues, generated evidence, payment timeline, adjudication, appeals, account restriction, audit log, operational alerts, and marketplace/AI/payment shutdown previews.

## Exit And Limits

Tap **Exit review**. The local session and all checkmarks, proof, PIN, and payment state are erased. Process restart also expires review mode. Reviewer mode never creates or receives a Supabase JWT, never reads Storage, never calls Stripe, and never reaches production administration.
