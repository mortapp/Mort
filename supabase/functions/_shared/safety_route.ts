export type RouteContext = {
  travel_mode: "WALK" | "DRIVE" | "BICYCLE" | "TRANSIT";
  origin_latitude: number;
  origin_longitude: number;
  destination_latitude: number;
  destination_longitude: number;
};

/** Read at most 1 KiB before parsing; reject coordinates and provider input. */
export async function readSafetyRouteApplication(
  request: Request,
): Promise<string> {
  const reader = request.body?.getReader();
  if (!reader) throw Error("invalid_route_request");
  const decoder = new TextDecoder();
  let text = "", size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 1024) {
        await reader.cancel();
        throw Error("invalid_route_request");
      }
      text += decoder.decode(value, { stream: true });
    }
    text += decoder.decode();
  } finally {
    reader.releaseLock();
  }
  const body = JSON.parse(text);
  if (
    !body || typeof body !== "object" || Array.isArray(body) ||
    Object.keys(body).some((key) => key !== "applicationId") ||
    typeof body.applicationId !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      body.applicationId,
    )
  ) {
    throw Error("invalid_route_request");
  }
  return body.applicationId;
}

/** Duration only. Never request or retain a polyline, directions or history. */
export async function computeSafetyDuration(
  context: RouteContext,
  key: string,
  fetcher: typeof fetch = fetch,
): Promise<number> {
  const response = await fetcher(
    "https://routes.googleapis.com/directions/v2:computeRoutes",
    {
      method: "POST",
      signal: AbortSignal.timeout(8000),
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": key,
        "X-Goog-FieldMask": "routes.duration",
      },
      body: JSON.stringify({
        origin: {
          location: {
            latLng: {
              latitude: context.origin_latitude,
              longitude: context.origin_longitude,
            },
          },
        },
        destination: {
          location: {
            latLng: {
              latitude: context.destination_latitude,
              longitude: context.destination_longitude,
            },
          },
        },
        travelMode: context.travel_mode,
      }),
    },
  );
  if (!response.ok) throw new Error("route_provider_unavailable");
  const duration = (await response.json())?.routes?.[0]?.duration;
  if (typeof duration !== "string" || !/^\d+(?:\.\d+)?s$/.test(duration)) {
    throw new Error("route_duration_unavailable");
  }
  const seconds = Math.ceil(Number(duration.slice(0, -1)));
  if (!Number.isFinite(seconds) || seconds < 0 || seconds > 86400) {
    throw new Error("route_duration_unavailable");
  }
  return seconds;
}
