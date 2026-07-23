# Purchase and Restore State Machine

1. Signed-in native user opens an optional paywall.
2. App initializes RevenueCat with the Supabase UID.
3. Offering/packages load; missing data returns an honest free state.
4. User selects a package and confirms through Apple.
5. Cancellation returns to the paywall with no unlock.
6. Success refreshes RevenueCat CustomerInfo and backend entitlement/credit providers.
7. Access is granted only from an active entitlement or server-granted consumable credit.
8. Restore refreshes CustomerInfo and never invents a purchase.
9. Webhook sync remains the authority for backend entitlement and credit records.

Native StoreKit transitions remain unverified until TestFlight.
