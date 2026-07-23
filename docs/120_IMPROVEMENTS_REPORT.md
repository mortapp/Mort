# 120 Improvements Report

Honest status for the Flutter rebuild. Items are grouped as implemented, partially implemented, and documented/planned.

## Implemented In Flutter Code
1. Created Flutter project in flutter_mort.
2. Kept Expo app as reference.
3. Set iOS bundle id com.mortapp.mobile.
4. Set Android package com.mortapp.mobile.
5. Renamed app label to MORT.
6. Added iOS camera permission copy.
7. Added iOS photo permission copy.
8. Added iOS notification permission copy.
9. Added iOS AdMob app id.
10. Created Flutter .env.example with placeholders only.
11. Added Flutter web app-ads.txt.
12. Verified root public app-ads.txt.
13. Added Supabase Flutter package.
14. Added Riverpod state layer.
15. Added GoRouter route map.
16. Added Supabase config guard.
17. Added Supabase initialize service.
18. Added auth repository.
19. Added profile repository.
20. Added jobs repository.
21. Added applications repository.
22. Added messaging repository.
23. Added safety repository.
24. Added guardian repository.
25. Added admin repository.
26. Added notifications repository.
27. Added uploads repository.
28. Added monetization repository.
29. Added Profile model.
30. Added Job model.
31. Added Application model.
32. Added Message model.
33. Added Notification model.
34. Added dark color system.
35. Added spacing system.
36. Added typography system.
37. Added Material theme.
38. Added MortScreen widget.
39. Added MortHeader widget.
40. Added MortCard widget.
41. Added MortButton widget.
42. Added form widgets.
43. Added safety/disclaimer widgets.
44. Added paywall cards.
45. Added ad slot widgets.
46. Added auth screens.
47. Added onboarding screens.
48. Added teen job feed.
49. Added job detail apply flow.
50. Added adult post job form.
51. Added applications review screen.
52. Added messages screen.
53. Added Safety Center.
54. Added notifications screen.
55. Added admin queue screen.
56. Added username settings.
57. Added paywall routes.
58. Added settings/legal/support routes.
59. Updated widget test.
60. Passed flutter analyze.
61. Passed flutter test.
62. Passed flutter build web.

## Partially Implemented
1. Proof upload repository wired but picker UI pending.
2. Verification upload repository wired but picker UI pending.
3. RevenueCat dependency installed but purchases disabled.
4. AdMob dependency installed but native rendering guarded.
5. Guardian invite works but full approvals UI pending.
6. Admin queues work generically but detail timelines pending.
7. Saved jobs backend reused but folder UI pending.
8. Skills route mapped but editor pending.
9. Availability route mapped but slot backend pending.
10. Portfolio route mapped but CRUD pending.
11. Goals route mapped but backend pending.
12. Adult jobs route mapped but edit/close pending.
13. Adult proof review route mapped but signed preview pending.
14. Support tickets backend exists but compose UI pending.
15. Reviews planned but not implemented.
16. Badges planned but not implemented.
17. Emergency contacts planned but not implemented.
18. Flutter push token registration pending.
19. Local notifications package added but native QA pending.
20. Ad frequency cap backend reused but UI pending.
21. Ad preferences UI saves but consent flow needs review.
22. Purchase entitlement display needs RevenueCat dashboard.
23. Username token purchase needs RevenueCat.
24. Job boost purchase needs RevenueCat.
25. Profile style packs need editor.
26. Hustle Academy lesson content is mapped only.
27. Guardian Plus feature copy is mapped only.
28. Adult Pro analytics copy is mapped only.
29. Manage subscription route is mapped only.
30. Native iPhone permissions still need device QA.
31. WASM warning documented but not fixed.
32. Android native IDs remain blank.
33. Android testing not done.
34. App Store legal review not done.
35. TestFlight not done.
36. iPhone manual testing not done.
37. RevenueCat webhooks still external.
38. AdMob app-ads website hosting still external.
39. No backend migration was added because not needed.
40. Remote smoke/RLS not rerun because backend unchanged.

## Documented Or Planned
1. Build portfolio CRUD.
2. Add image picker proof UI.
3. Add image picker verification UI.
4. Add report attachment UI.
5. Add saved folder editor.
6. Add skill multi-select.
7. Add availability slot editor.
8. Add weekly goal editor.
9. Add monthly goal editor.
10. Add reviews backend.
11. Add badges backend.
12. Add emergency contacts backend.
13. Add native push registration.
14. Add RevenueCat initialization with appUserID.
15. Add RevenueCat offerings display.
16. Add RevenueCat purchase flow.
17. Add RevenueCat restore validation.
18. Add RevenueCat webhook processor if needed.
19. Add AdMob native banner render after test devices.
20. Add rewarded ad safe perks.
21. Add consent management flow.
22. Add adult job edit.
23. Add adult job close.
24. Add adult job duplicate.
25. Add applicant detail timeline.
26. Add guardian approval detail actions.
27. Add guardian permission toggles.
28. Add guardian digest.
29. Add admin report evidence timeline.
30. Add admin verification signed preview.
31. Add admin user detail.
32. Add admin moderation notes.
33. Add support ticket composer.
34. Add support reply thread.
35. Add App Store privacy labels.
36. Add teen labor legal review.
37. Add moderation staffing plan.
38. Add TestFlight pilot checklist.
39. Add iPhone camera QA evidence.
40. Add iPhone notification QA evidence.
