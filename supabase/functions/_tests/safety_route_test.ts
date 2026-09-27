import {
  computeSafetyDuration,
  readSafetyRouteApplication,
} from "../_shared/safety_route.ts";

Deno.test("route input permits only an application ID and bounds streamed bytes", async () => {
  const id = "00000000-0000-4000-8000-000000000001";
  const valid = new Request("https://example.invalid", {
    method: "POST",
    body: JSON.stringify({ applicationId: id }),
  });
  if (await readSafetyRouteApplication(valid) !== id) {
    throw Error("Application lost");
  }
  for (
    const body of [
      JSON.stringify({ applicationId: id, latitude: 39.7 }),
      "x".repeat(1025),
      "null",
    ]
  ) {
    let denied = false;
    try {
      await readSafetyRouteApplication(
        new Request("https://example.invalid", { method: "POST", body }),
      );
    } catch (_) {
      denied = true;
    }
    if (!denied) throw Error("Untrusted route input accepted");
  }
});

const context = {
  travel_mode: "WALK" as const,
  origin_latitude: 39.7,
  origin_longitude: -86.1,
  destination_latitude: 39.8,
  destination_longitude: -86.2,
};
Deno.test("duration request excludes route history and returns bounded seconds", async () => {
  const fake: typeof fetch = async (_url, init) => {
    const headers = init?.headers as Record<string, string>;
    if (headers["X-Goog-FieldMask"] !== "routes.duration") {
      throw Error("Unnecessary route fields");
    }
    if (JSON.parse(init!.body as string).travelMode !== "WALK") {
      throw Error("Travel mode changed");
    }
    return new Response(JSON.stringify({ routes: [{ duration: "599.5s" }] }));
  };
  if (await computeSafetyDuration(context, "synthetic-key", fake) !== 600) {
    throw Error("Duration rounding failed");
  }
});
Deno.test("provider failure and malformed durations never create an ETA", async () => {
  for (
    const reply of [
      new Response("error", { status: 503 }),
      new Response(JSON.stringify({ routes: [{ duration: "-10s" }] })),
      new Response(JSON.stringify({ routes: [{ duration: "999999s" }] })),
      new Response(JSON.stringify({ routes: [] })),
    ]
  ) {
    let rejected = false;
    try {
      await computeSafetyDuration(context, "synthetic-key", async () => reply);
    } catch (_) {
      rejected = true;
    }
    if (!rejected) throw Error("Invalid provider response accepted");
  }
});
