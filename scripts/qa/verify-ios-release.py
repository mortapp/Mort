#!/usr/bin/env python3
"""Read-only macOS preflight for an owner-provided signed .xcarchive and IPA.

Does not sign, export, upload, or echo the profile, UDIDs, or private material.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import plistlib
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from zipfile import BadZipFile, ZipFile


class VerificationError(Exception):
    pass


def require(condition, description):
    if not condition:
        raise VerificationError(description)


def evaluate(info, signed, profile, team, mode, require_push, domains, now):
    bundle = "com.mortapp.mobile"
    require(info.get("CFBundleIdentifier") == bundle, "unexpected bundle identifier")
    require(info.get("CFBundleShortVersionString") == "0.9.16", "unexpected build version")
    require(str(info.get("CFBundleVersion")) == "111", "unexpected build number")
    require(info.get("MinimumOSVersion") == "15.0", "unexpected deployment target")
    callback = any(
        bundle in entry.get("CFBundleURLSchemes", [])
        for entry in info.get("CFBundleURLTypes", [])
    )
    require(callback, "approved native OAuth URL scheme missing")
    require(info.get("FirebaseMessagingAutoInitEnabled") is False, "FCM auto-init not disabled")
    require(info.get("GADDelayAppMeasurementInit") is True, "ads measurement delay missing")

    expiration = profile.get("ExpirationDate")
    require(isinstance(expiration, datetime), "profile expiry is missing")
    if expiration.tzinfo is None:
        expiration = expiration.replace(tzinfo=timezone.utc)
    require(expiration > now, "provisioning profile is expired")
    require(team in profile.get("TeamIdentifier", []), "profile team mismatch")
    require(not profile.get("ProvisionsAllDevices"), "unexpected enterprise profile")
    devices = profile.get("ProvisionedDevices", [])
    require(bool(devices) == (mode == "ad-hoc"), "profile device scope is not the expected export mode")
    authorized = profile.get("Entitlements", {})
    for entitlements in (authorized, signed):
        require(entitlements.get("application-identifier") == f"{team}.{bundle}", "app entitlement mismatch")
        require(entitlements.get("get-task-allow", False) is False, "distribution must not allow debugger attachment")
        require(entitlements.get("com.apple.developer.team-identifier") == team, "entitlement team mismatch")
        require(
            entitlements.get("aps-environment") == "production" if require_push
            else "aps-environment" not in entitlements,
            "APNs entitlement is not the explicitly expected configuration",
        )
    effective_domains = set(signed.get("com.apple.developer.associated-domains", []))
    require(effective_domains == set(domains), "effective Associated Domains do not exactly match the expected set")
    if domains:
        permitted_domains = authorized.get("com.apple.developer.associated-domains", [])
        require(
            "*" in permitted_domains or set(domains).issubset(permitted_domains),
            "Associated Domains are not authorized by the profile",
        )


def read_command(label, *args):
    result = subprocess.run(args, check=False, capture_output=True)
    require(result.returncode == 0, f"{label} failed")
    return result


def sha256(path):
    with path.open("rb") as file:
        return hashlib.file_digest(file, "sha256").hexdigest()


def unpack_ipa(ipa, destination):
    """Extract only one iOS Payload, without following special ZIP entries."""
    with ZipFile(ipa) as archive:
        entries = []
        seen = set()
        apps = set()
        expanded_size = 0
        for entry in archive.infolist():
            raw = entry.orig_filename
            path = PurePosixPath(raw)
            require(
                raw == entry.filename and "\\" not in raw and not path.is_absolute()
                and all(part not in {"", ".", ".."} for part in raw.rstrip("/").split("/")),
                "unsupported path in IPA",
            )
            if path.parts[0] != "Payload":
                continue
            mode = entry.external_attr >> 16
            kind = stat.S_IFMT(mode)
            require(kind in (0, stat.S_IFDIR if entry.is_dir() else stat.S_IFREG),
                    "unsupported non-regular entry in IPA Payload")
            key = str(path).casefold()
            require(key not in seen, "duplicate path in IPA Payload")
            seen.add(key)
            if len(path.parts) >= 2:
                require(path.parts[1].endswith(".app"), "unexpected item in IPA Payload")
                apps.add(path.parts[1])
            else:
                require(entry.is_dir(), "IPA Payload must be a directory")
            expanded_size += entry.file_size
            entries.append((entry, path, mode))
        require(len(apps) == 1, "IPA must contain exactly one top-level application")
        require(expanded_size <= 2 * 1024**3, "IPA Payload exceeds the 2 GiB verification limit")
        for entry, path, mode in entries:
            target = destination.joinpath(*path.parts)
            if entry.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(entry) as source, target.open("xb") as output:
                    shutil.copyfileobj(source, output)
                target.chmod(0o700 if mode & 0o111 else 0o600)
    app = destination / "Payload" / next(iter(apps))
    require(app.is_dir(), "IPA application bundle is not a directory")
    return app


def code_identity(uuid_output):
    uuids = re.findall(rb"^UUID: ([A-F0-9-]{36}) \(arm64\)", uuid_output, re.I | re.M)
    require(len(uuids) == 1, "expected one arm64 executable UUID")
    return uuids[0].lower()


def verify_same_build(archived, exported):
    require(archived["binary_uuid"] == exported["binary_uuid"],
            "exported executable does not match the archive UUID")
    require(archived["privacy_manifest_sha256"] == exported["privacy_manifest_sha256"],
            "exported app privacy manifest differs from archive")


def verify_app(app, args):
    require(app.is_dir(), "application bundle missing")
    require((app / "embedded.mobileprovision").is_file(), "embedded provisioning profile missing")
    read_command("strict signature verification", "codesign", "--verify", "--deep", "--strict", str(app))
    signature = read_command("signature inspection", "codesign", "-d", "--verbose=4", str(app))
    require(b"Authority=Apple Distribution:" in signature.stderr, "Apple Distribution signing authority missing")
    signer_team = f"TeamIdentifier={args.team_id}".encode()
    require(signer_team in signature.stderr.splitlines(), "code signature team mismatch")
    with (app / "Info.plist").open("rb") as source:
        info = plistlib.load(source)
    executable = info.get("CFBundleExecutable")
    require(isinstance(executable, str) and re.fullmatch(r"[A-Za-z0-9._-]+", executable)
            and executable not in {".", ".."}, "invalid bundle executable")
    binary = app / executable
    require(read_command("Mach-O inspection", "xcrun", "lipo", "-archs", str(binary)).stdout.strip() == b"arm64",
            "expected a device arm64 binary")
    signed = plistlib.loads(read_command("signed entitlements", "codesign", "-d", "--entitlements", "-", str(app)).stdout)
    profile = plistlib.loads(read_command("provisioning profile decode", "security", "cms", "-D", "-i",
                                         str(app / "embedded.mobileprovision")).stdout)
    with tempfile.TemporaryDirectory(prefix="mort-ios-signature-") as temporary:
        prefix = Path(temporary) / "public-certificate-"
        read_command("certificate extraction", "codesign", "-d", "--extract-certificates", str(prefix), str(app))
        with Path(f"{prefix}0").open("rb") as leaf:
            require(leaf.read() in profile.get("DeveloperCertificates", []),
                    "the build signer is not authorized by the embedded profile")
    evaluate(info, signed, profile, args.team_id, args.profile_type, args.push == "required",
             args.associated_domain, datetime.now(timezone.utc))
    manifest = app / "PrivacyInfo.xcprivacy"
    with manifest.open("rb") as source:
        require(isinstance(plistlib.load(source), dict), "invalid root privacy manifest")
    return {
        "binary_uuid": code_identity(read_command("Mach-O UUID inspection", "xcrun", "dwarfdump", "--uuid", str(binary)).stdout),
        "privacy_manifest_sha256": sha256(manifest),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--ipa", type=Path, help="verify the raw exported IPA as well as the archive")
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--profile-type", required=True, choices=("app-store", "ad-hoc"))
    parser.add_argument("--push", required=True, choices=("required", "off"))
    parser.add_argument("--associated-domain", action="append", default=[])
    args = parser.parse_args()
    require(sys.platform == "darwin", "signed artifact validation requires macOS")
    require(re.fullmatch(r"[A-Z0-9]{10}", args.team_id), "supply the owner-approved Apple Team ID")
    app = args.archive.resolve() / "Products" / "Applications" / "Runner.app"
    archived = verify_app(app, args)
    print("PASS archive: distribution signature, arm64, bundle/version, profile scope, OAuth scheme and effective entitlements")
    if args.ipa:
        digest = sha256(args.ipa)
        with tempfile.TemporaryDirectory(prefix="mort-ipa-check-") as temporary:
            exported = verify_app(unpack_ipa(args.ipa, Path(temporary)), args)
            verify_same_build(archived, exported)
        require(digest == sha256(args.ipa), "IPA changed during inspection")
        print(f"PASS IPA: distribution policy and archive consistency; SHA-256 {digest}")
    else:
        print("NOT VERIFIED: no exported IPA supplied")
    print("Not tested: callbacks, APNs or Keychain runtime, Apple privacy report, store submission, or on-device behavior")


if __name__ == "__main__":
    try:
        main()
    except VerificationError as error:
        sys.exit(f"BLOCKED: {error}")
    except (OSError, ValueError, TypeError, KeyError, BadZipFile, plistlib.InvalidFileException):
        sys.exit("BLOCKED: missing or malformed artifact data")
