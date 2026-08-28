# App Store Connect IAP Setup

No App Store Connect API credentials were visible in this Codex session, so Apple-side setup was not automated.

Expected credentials for future automation:

- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY_PATH`
- `APP_STORE_CONNECT_APP_ID`

## Manual Steps

1. Open App Store Connect.
2. Select the MORT iOS app with bundle ID `com.mortapp.mobile`.
3. Enable In-App Purchase capability in the app record and Xcode project/signing setup.
4. Create the auto-renewable subscription products:
   - `mort_plus_monthly`
   - `mort_plus_yearly`
   - `mort_adult_pro_monthly`
   - `mort_guardian_plus_monthly`
5. Create the non-consumables:
   - `mort_plus_lifetime`
   - `mort_ad_free_lifetime`
   - `mort_profile_style_pack`
6. Create the consumables:
   - `mort_username_change_token_1`
   - `mort_job_boost_1`
7. Use `docs/APP_STORE_CONNECT_PRODUCT_MATRIX.md` for type, target price, entitlement, offering, review notes, and screenshots.
8. Add review screenshots for each purchase surface.
9. Connect the App Store products to the RevenueCat app.
10. Run TestFlight sandbox purchase, restore, cancel, and webhook tests before any real-user launch.

## App Review Notes

- MORT does not sell job placement, escrow, or payment processing.
- Safety tools stay free.
- Basic job applying stays free.
- Basic Guardian Mode stays free.
- Report, block, Safety Ping, messaging safety scanner, and moderation stay free.
- Boosts never bypass moderation or verification.
