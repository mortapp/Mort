-- MORT triggers on platform-owned auth.users (live production definitions, 2026-11-16)
drop trigger if exists on_auth_user_created_mort on auth.users;
CREATE TRIGGER on_auth_user_created_mort AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION private.handle_new_user();
drop trigger if exists mort_enforce_minor_school_email_on_auth_email_change on auth.users;
CREATE TRIGGER mort_enforce_minor_school_email_on_auth_email_change BEFORE UPDATE OF email ON auth.users FOR EACH ROW WHEN (((old.email)::text IS DISTINCT FROM (new.email)::text)) EXECUTE FUNCTION private.enforce_minor_school_email_on_auth_email_change();
