-- earnings-safety-overview, benefits-and-teen-earnings, and
-- expenses-and-receipts advertised themselves to adult/guardian audiences
-- (audience included 'adult'/'guardian'), but their navigation_route values
-- (/financial, /financial/benefits, /financial/expenses) are all guarded
-- role: UserRole.teen in app_router.dart, and no adult/guardian-facing
-- equivalent screen exists anywhere in the app. An adult or guardian who
-- opened one of these MORT Guide sources hit WrongRoleScreen.
--
-- No adult/guardian-facing financial screen exists to redirect to instead,
-- and the content itself is written in first/second person to the person
-- doing the earning ("You can record work-related expenses...") rather than
-- framed for a guardian/adult reader -- so the correct fix is narrowing the
-- audience metadata to match the actual (teen-only) destination, not
-- exposing the teen route to other roles.
--
-- Corrective forward migration; 20260831120000_mort_earnings_safety_v1.sql
-- (already applied) is not edited directly.

update public.support_kb_documents
set audience = array['teen']::text[], updated_at = now()
where slug in ('earnings-safety-overview', 'benefits-and-teen-earnings', 'expenses-and-receipts');
;
