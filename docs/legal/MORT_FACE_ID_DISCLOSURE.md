# MORT Face ID and Touch ID Disclosure

> **DRAFT — NOT ATTORNEY REVIEWED OR LEGALLY APPROVED**
>
> This document is an original MORT working draft for review by licensed counsel and qualified youth-safety, privacy, labor, insurance, and operations professionals. It is not legal advice, does not make MORT legally approved, and must not be presented as a final contract or policy.

## Purpose and status

This disclosure explains local device authentication as an account-protection control, not an identity-verification system.

## Device protection

MORT uses Face ID or Touch ID to protect private information on this device. It does not verify your legal identity. Supported controls may protect app reopening, private location, incident status, proof actions, data export, deletion requests, support changes, and reviewer access.

## Data boundary

Apple evaluates the biometric locally. MORT receives an authentication result, not a face image, fingerprint, biometric template, or sensor data. No biometric data is sent to Supabase.

## Fallback and failure

The app handles unavailable, not enrolled, user canceled, failed match, lockout, system canceled, enrollment change, and device-passcode fallback states. A success cannot raise an identity-verification level.

## Web

Flutter Web may explain passkeys or WebAuthn where supported but must not claim direct Face ID access or treat a passkey as legal identity proof.

## Required professional review

Before publication, licensed counsel must determine enforceability, age and capacity rules, required parental consent, electronic-signature requirements, labor classification, wage law, privacy and biometric duties, negligence and statutory duties, dispute terms, insurance, indemnification, arbitration, class-action treatment, limitation of liability, governing law, and nonwaivable rights for each launch jurisdiction. Material revisions require a new version, content hash, effective date, and affirmative reacceptance where applicable.
