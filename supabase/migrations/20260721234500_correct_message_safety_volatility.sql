-- Match the volatility classification of the regex and text expressions used by
-- the scanner. This changes planner metadata only; safety behavior is unchanged.
alter function private.classify_message_safety(text) stable;
