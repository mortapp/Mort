-- MORT Unicode and obfuscation screening regression contract.
-- Run only on the isolated QA database after the message safety migrations.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public, auth, pg_catalog;
select plan(10);

select is(private.normalize_message_body('ＮＵＤＥＳ'), 'nudes',
  'NFKC normalizes full-width Latin characters');
select is(private.normalize_message_body(U&'n\200Bu\200Bd\200Be\200Bs'), 'nudes',
  'zero-width formatting characters are removed');
select is(private.normalize_message_body('ѕnар'), 'snap',
  'Cyrillic homoglyphs normalize to their Latin equivalents');
select is(private.normalize_message_body('ΑΒΕΖΗΙΚΜΝΟΡΤΥΧ'), 'abezhikmnoptyx',
  'Greek homoglyphs normalize to their Latin equivalents');

select is(private.scan_message_body('n.u.d.e.s', false), 'blocked',
  'punctuation-separated explicit terms are blocked');
select is(private.scan_message_body('D M M E on Insta gram', false), 'blocked',
  'spaced off-platform redirection is blocked');
select is(private.scan_message_body('dont tell your parents about this', false), 'blocked',
  'secrecy pressure is blocked after normalization');
select is(private.scan_message_body('text me on telegram', true), 'blocked',
  'off-platform contact is blocked regardless of sender role');
select is(private.scan_message_body('earn $500 a day for easy work', false), 'flag',
  'unrealistic earnings lures are held for human review');
select is(private.scan_message_body('What time should I arrive to mow the lawn?', false), 'clean',
  'ordinary job coordination remains deliverable');

select * from finish();
rollback;
