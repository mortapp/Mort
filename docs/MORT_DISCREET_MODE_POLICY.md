# MORT Discreet Mode Policy

Status: implementation-aligned privacy draft. Physical iPhone behavior still requires Xcode and device testing.

## Purpose

Discreet Mode protects privacy for users in shared-device, unstable, or unsafe living situations. It is not a tool to disguise illegal activity.

## Hosted protections

When enabled, the notification trigger replaces the title with `MORT notification`, replaces the body with `Open MORT to view this update.`, strips sensitive data, preserves only a bounded route, and records that no job address or sensitive details are included.

Private resource bookmarks, Future Independence data, Support Circle configuration, earnings, and no-address setup choices remain protected by RLS regardless of notification mode.

## Native behavior

The Swift interface can request device authentication and configure an automatic-lock preference, but Face ID/passcode enforcement and quick-exit navigation require physical iPhone testing. Notification presentation must be tested in foreground, background, lock screen, preview-disabled, and shared-device conditions.

## Web behavior

The Flutter PWA supports hosted generic notification preferences and route-level quick exit. Browsers do not provide MORT with reliable native Face ID/passcode app-lock enforcement, and browser history may remain after quick exit. The PWA says so instead of claiming native protection.

## Content exclusions

Never place exact job addresses, abuse, homelessness, shelter, foster, counselor, school, family, document-review, crisis-resource, or Safety Ping detail in notification previews, widgets, analytics, or public activity.
