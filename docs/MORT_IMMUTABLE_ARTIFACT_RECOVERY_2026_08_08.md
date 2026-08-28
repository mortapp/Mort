# MORT Immutable Artifact Recovery

Date: 2026-08-08 (America/Indianapolis)

## Incident

The first `0.9.14+104` package attempt exposed a hardcoded output path in
`scripts/generate-release-sbom.mjs`. The generator wrote a current-source SBOM
over:

```text
artifacts/release-0.9.13+103/MORT_SBOM.cdx.json
```

No historical APK, AAB, symbols ZIP, source ZIP, build manifest, release
manifest, report, or other release file changed. The affected file was the
historical SBOM only.

## Original Evidence

The unchanged `0.9.13+103` release manifest records the original SBOM as:

```text
Bytes: 427038
SHA-256: ADEF1B62CB7656E56F59E2D15AEF6ACA1C4D88CC220B702CF01C5074C9395037
```

The accidental overwrite was:

```text
Bytes: 425811
SHA-256: A243016E383F830390FC9E5D60CC0473345923A59D14263A1E53E65AF64396CD
```

## Recovery

The original `0.9.13+103` source ZIP first passed its recorded SHA-256 check.
It was extracted into ignored recovery storage, its frozen pnpm and Flutter
dependency graphs were restored, and its original generator produced:

```text
Application version: 0.9.13+103
Dependency components: 1111
Bytes: 427038
Reconstructed SHA-256: 47D6A25615488AD6C7EE3C30C984BEAF49EC2EDEDBF28001D1B555DD4A51FBB2
```

The component count and byte length match the original inventory. The exact
original bytes cannot be recovered because CycloneDX `serialNumber` and
`metadata.timestamp` were randomly/time generated and no second copy of the
original SBOM exists. The reconstructed inventory now occupies the historical
SBOM path, while the unchanged release manifest preserves the original expected
hash and therefore exposes the mismatch.

Recovery copies are retained under ignored:

```text
backups/immutable-release-recovery/
```

## Prevention

- The SBOM generator now requires an explicit `--output` argument.
- It derives the only allowed release directory from the authoritative Flutter
  `version:` value.
- It rejects any output path that does not exactly match that release.
- The package script passes and verifies the current versioned SBOM path.
- Windows dependency collection no longer uses Node's `shell: true` path.

## Disposition

This incident does not change the signed `0.9.13+103` or `0.9.14+104` app
binaries. It does mean the historical `0.9.13+103` SBOM is a reconstruction,
not an immutable byte-for-byte original. Do not use its current hash as the
original hash; use the unchanged historical manifest for that evidence.
