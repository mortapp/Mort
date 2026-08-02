-- Match PostgreSQL's volatility classification for the JSON operations used by
-- the push payload sanitizer. This does not change its output or permissions.
alter function private.safe_push_data(text, jsonb) stable;
