#!/usr/bin/env python3
"""Read-only macOS preflight for an owner-provided signed .xcarchive.

Does not sign, export, upload, or echo the profile, UDIDs, or private material.
"""

import argparse
from datetime import datetime, timezone
import plistlib
from pathlib import Path
import re
import subprocess
import sys
import tempfile


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--profile-type", required=True, choices=("app-store", "ad-hoc"))
    parser.add_argument("--push", required=True, choices=("required", "off"))
    parser.add_argument("--associated-domain", action="append", default=[])
    args = parser.parse_args()
    require(sys.platform == "darwin", "signed archive validation requires macOS")
    require(re.fullmatch(r"[A-Z0-9]{10}", args.team_id), "supply the owner-approved Apple Team ID")
    app = args.archive.resolve() / "Products" / "Applications" / "Runner.app"
    require(app.is_dir(), "Runner.app not found inside archive")
    require((app / "embedded.mobileprovision").is_file(), "embedded provisioning profile missing")
    read_command("strict signature verification", "codesign", "--verify", "--deep", "--strict", str(app))
    signature = read_command("signature inspection", "codesign", "-d", "--verbose=4", str(app))
    require(b"Authority=Apple Distribution:" in signature.stderr, "Apple Distribution signing authority missing")
    signer_team = f"TeamIdentifier={args.team_id}".encode()
    require(signer_team in signature.stderr.splitlines(), "code signature team mismatch")
    require(read_command("Mach-O inspection", "xcrun", "lipo", "-archs", str(app / "Runner")).stdout.strip() == b"arm64",
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
    with (app / "Info.plist").open("rb") as source:
        info = plistlib.load(source)
    evaluate(info, signed, profile, args.team_id, args.profile_type, args.push == "required",
             args.associated_domain, datetime.now(timezone.utc))
    print("PASS: distribution signature, arm64, bundle/version, profile scope, OAuth scheme and effective entitlements")
    print("Not tested: callbacks, APNs or Keychain runtime, Apple privacy report, store submission, or on-device behavior")


if __name__ == "__main__":
    try:
        main()
    except VerificationError as error:
        sys.exit(f"BLOCKED: {error}")
    except (OSError, ValueError, TypeError, KeyError, plistlib.InvalidFileException):
        sys.exit("BLOCKED: missing or malformed artifact metadata")
