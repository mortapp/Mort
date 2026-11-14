insert into private.message_safety_rules(id,pattern,description,category,severity,active)
values
 ('direct threats','(?i)(i will kill you|kill you|hurt you|beat you|i know where you live|i will find you|watching your house|bring a weapon|i have a gun)','direct threats or intimidation','threats','block',true),
 ('coercion blackmail','(?i)(blackmail|expose you|post your photos|ruin you unless|pay me or|do this or else)','blackmail and coercive threats','coercion','block',true),
 ('sensitive information request','(?i)(send me|give me|what is|tell me)[^\\n]{0,50}\\y(home address|school address|student number|social security|passport number|license number)\\y','requests for sensitive identity or location data','personal_information','block',true),
 ('exact street address','(?i)(^|[^0-9])[0-9]{1,6}[[:space:]]+[a-z0-9.''-]+([[:space:]]+[a-z0-9.''-]+){0,4}[[:space:]]+(street|st|avenue|ave|road|rd|drive|dr|lane|ln|court|ct|boulevard|blvd|way|parkway|pkwy|place|pl)([^a-z]|$)','sharing an exact street address in job chat','personal_information','block',true),
 ('unsafe payment pressure','(?i)\\y(gift card|crypto payment|deposit first|upfront fee|cashapp|venmo|zelle|paypal|pay or else|withhold pay)\\y','off-platform payment requests and unsafe payment pressure','financial','block',true),
 ('harassment and humiliation','(?i)\\y(you are worthless|stupid kid|stupid adult|hate you|i will humiliate you)\\y','potential harassment or humiliation','harassment','flag',true)
on conflict(id) do update set pattern=excluded.pattern,description=excluded.description,
category=excluded.category,severity=excluded.severity,active=true;
