const defaultWindowSeconds = 600;
const minimumRemainingSeconds = 30;

export function delayUntilStableRateLimitWindowMs(
  epochSeconds,
  windowSeconds = defaultWindowSeconds,
) {
  if (
    !Number.isFinite(epochSeconds) ||
    !Number.isSafeInteger(windowSeconds) ||
    windowSeconds < minimumRemainingSeconds
  ) {
    throw new RangeError("Invalid fixed-window rate-limit clock value.");
  }

  const position = ((epochSeconds % windowSeconds) + windowSeconds) %
    windowSeconds;
  const remainingSeconds = windowSeconds - position;
  if (remainingSeconds >= minimumRemainingSeconds) return 0;

  // Wake after the boundary, with one second for clock and timer precision.
  return Math.ceil((remainingSeconds + 1) * 1000);
}
