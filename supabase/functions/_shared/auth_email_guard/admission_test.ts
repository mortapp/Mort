import { Admission } from "./admission.ts";
function check(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
const source = (n: number) => n.toString(16).padStart(64, "0");
Deno.test("owned-source admission is capped at two, canonical item at one, with clean release", () => {
  const admission = new Admission(),
    a = admission.acquire(source(1)),
    b = admission.acquire(source(1));
  check(
    a && b && !admission.acquire(source(1)),
    "Source third request must receive Busy without admission",
  );
  const id = crypto.randomUUID();
  check(
    a.bind(id) && !b.bind(id),
    "Same canonical challenge has one active checker",
  );
  b.release();
  const other = admission.acquire(source(2));
  check(
    other && other.bind(crypto.randomUUID()),
    "Independent source/challenge must remain available",
  );
  a.release();
  a.release();
  other.release();
  check(
    admission.snapshot().active === 0,
    "Release is idempotent and removes all active counters",
  );
});
Deno.test("global admission rejects sixty-fifth, then restores legitimate access", () => {
  const admission = new Admission();
  const entries = Array.from(
    { length: 64 },
    (_, i) => admission.acquire(source(i + 1)),
  );
  check(
    entries.every(Boolean) && !admission.acquire(source(65)) &&
      admission.snapshot().active === 64,
    "At most sixty-four live admission tickets",
  );
  entries.forEach((ticket) => ticket?.release());
  check(
    admission.acquire(source(65)) !== null,
    "Legitimate admission must recover after contention",
  );
});
