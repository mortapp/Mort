const blockedTerms = [
  "cashapp",
  "venmo",
  "zelle",
  "paypal",
  "square link",
  "instagram",
  "insta",
  "snapchat",
  "tiktok",
  "discord",
  "telegram",
  "whatsapp",
  "signal",
  "kik",
  "home address",
  "come to my house",
  "meet alone",
  "don't tell",
  "dont tell",
  "keep this secret",
  "off app",
  "upfront fee",
  "deposit first",
  "sexual",
  "nude",
  "threat",
  "secret"
];

const phonePattern = /(?:\+?1[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?)\d{3}[-.\s]?\d{4}/;
const emailPattern = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i;
const socialHandlePattern = /(?:^|\s)@[A-Za-z0-9_.]{2,}/;
const cashAppPattern = /\$[A-Za-z][A-Za-z0-9_]{1,20}/;

export type SafetyScan = {
  status: "clean" | "blocked";
  reason?: string;
};

export function scanMessageBody(body: string): SafetyScan {
  const normalized = body.trim().toLowerCase();

  if (!normalized) {
    return { status: "blocked", reason: "Message cannot be empty." };
  }

  if (phonePattern.test(body)) {
    return { status: "blocked", reason: "Phone numbers must stay off MORT chat." };
  }

  if (emailPattern.test(body)) {
    return { status: "blocked", reason: "Email addresses must stay off MORT chat." };
  }

  if (cashAppPattern.test(body) || socialHandlePattern.test(body)) {
    return { status: "blocked", reason: "Payment tags and social handles must stay off MORT chat." };
  }

  const term = blockedTerms.find((candidate) => normalized.includes(candidate));
  if (term) {
    return { status: "blocked", reason: `Message includes unsafe contact or secrecy language: ${term}.` };
  }

  return { status: "clean" };
}
