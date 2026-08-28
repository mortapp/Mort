# Google Play Billing Product Setup

MORT uses Play Billing only for optional Android digital benefits. Job funding and payouts are never Play products.

Create the subscription `mort_plus` with base plans `monthly-auto` and `annual-auto`. Create one-time products `mort_theme_neon_pack`, `mort_theme_midnight_pack`, `mort_profile_frames_pack_01`, and `mort_portfolio_layouts_pack_01`. Product IDs must match `private.store_products` exactly. The planning targets are USD 1.99/month, USD 14.99/year, and USD 0.99 per one-time pack, but prices and localized text are configured in Play Console; Flutter renders Play-returned price strings and does not treat documentation targets as final truth. Do not enable a free trial initially.

Keep every product inactive in MORT server controls until:

1. The AAB containing Billing is uploaded to a test track.
2. Base plans/offers are active and available to the tester country.
3. A Google Cloud service account is linked with the minimum Android Publisher permissions.
4. `google-play-verify-purchase` and RTDN are deployed with server-only credentials.
5. License tests cover purchase, pending, cancel, refund/revoke, restore, reinstall, duplicate token, replay, offline verification, and account switching.

The server verifies package, product, environment, account binding, purchase state, acknowledgement, idempotency, and token hash before granting an entitlement. Raw purchase tokens are not stored. Free job applying, Guardian Mode, reporting, blocking, Safety Ping, and safety help remain free.
