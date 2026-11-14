insert into private.message_safety_rules(id,pattern,description,category,severity,active)
values
 ('sensitive information request','(?i)(send me|give me|what is|tell me).{0,50}(home address|school address|student number|social security|passport number|license number)','requests for sensitive identity or location data','personal_information','block',true),
 ('unsafe payment pressure','(?i)(gift[[:space:]]*cards?|crypto payment|deposit first|upfront fee|cashapp|venmo|zelle|paypal|pay or else|withhold pay)','off-platform payment requests and unsafe payment pressure','financial','block',true),
 ('harassment and humiliation','(?i)(you are worthless|stupid kid|stupid adult|hate you|i will humiliate you)','potential harassment or humiliation','harassment','flag',true)
on conflict(id) do update set pattern=excluded.pattern,description=excluded.description,
category=excluded.category,severity=excluded.severity,active=true;
