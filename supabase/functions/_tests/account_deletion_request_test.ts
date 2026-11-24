import { assertEquals } from "jsr:@std/assert@1";
import { readDeletionRequest } from "../account-deletion-processor/request.ts";

function request(body?: BodyInit, contentLength?: string): Request {
  return new Request("http://localhost/", {
    method: "POST",
    body,
    headers: contentLength ? { "content-length": contentLength } : {},
  });
}

Deno.test("deletion worker preserves intentional queue polling", async () => {
  for (const body of [undefined, "", "  ", "{}"]) {
    assertEquals(await readDeletionRequest(request(body)), {
      ok: true,
      requestId: null,
    });
  }
});

Deno.test("deletion worker accepts an exact UUID", async () => {
  const requestId = "11111111-1111-4111-8111-111111111111";
  assertEquals(
    await readDeletionRequest(request(JSON.stringify({ requestId }))),
    { ok: true, requestId },
  );
});

Deno.test("deletion worker rejects malformed JSON and invalid UTF-8", async () => {
  for (const body of ["{", new Uint8Array([0xff])]) {
    assertEquals(await readDeletionRequest(request(body)), {
      ok: false,
      status: 400,
      code: "invalid_json",
    });
  }
});

Deno.test("deletion worker rejects non-object payloads", async () => {
  for (const body of ["[]", "null", "1", '"text"']) {
    assertEquals(await readDeletionRequest(request(body)), {
      ok: false,
      status: 400,
      code: "invalid_json_object",
    });
  }
});

Deno.test("deletion worker rejects null, coercion and unrecognized fields", async () => {
  for (
    const requestId of [
      null,
      [],
      ["11111111-1111-4111-8111-111111111111"],
      1,
      "invalid",
    ]
  ) {
    assertEquals(
      await readDeletionRequest(request(JSON.stringify({ requestId }))),
      {
        ok: false,
        status: 400,
        code: "invalid_request_id",
      },
    );
  }
  assertEquals(
    await readDeletionRequest(request('{"request_id":"mistyped"}')),
    {
      ok: false,
      status: 400,
      code: "unexpected_request_field",
    },
  );
});

Deno.test("deletion worker caps declared and actual byte sizes", async () => {
  for (
    const req of [
      request("{}", "4097"),
      request("é".repeat(2049)),
      request(" ".repeat(4097), "1"),
    ]
  ) {
    assertEquals(await readDeletionRequest(req), {
      ok: false,
      status: 413,
      code: "payload_too_large",
    });
  }
});
