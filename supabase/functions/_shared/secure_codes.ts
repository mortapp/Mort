// Rejection sampling keeps every eight-digit school code equally likely.
// The callback allows deterministic boundary tests without logging real codes.
export function randomEightDigitCode(
  fill: (values: Uint32Array) => void = (values) => {
    crypto.getRandomValues(values);
  },
): string {
  const values = new Uint32Array(1);
  do {
    fill(values);
  } while (values[0] >= 4_200_000_000);
  return String(values[0] % 100_000_000).padStart(8, "0");
}

export const SCHOOL_CODE_EXPIRY_SECONDS = 600;
