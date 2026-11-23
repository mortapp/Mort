#!/usr/bin/env python3
"""Inspect owner-supplied Android release files offline, without signing or rebuilding."""

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from zipfile import ZipFile


APP_ID = "com.mortapp.mobile"
ANDROID = "{http://schemas.android.com/apk/res/android}"
BUNDLETOOL_SHA = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29"
NATIVE = re.compile(r"(?:(?P<module>[A-Za-z0-9_]+)/)?lib/(?P<abi>[A-Za-z0-9_-]+)/(?P<name>[^/]+\.so)")


def require(ok, message):
    if not ok:
        raise ValueError(message)


def digest(value):
    normal = value.replace(":", "").lower()
    require(re.fullmatch(r"[a-f0-9]{64}", normal), "Invalid SHA-256 fingerprint.")
    return normal


def sha(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def run(*cmd):
    result = subprocess.run(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        encoding="utf-8", errors="replace", check=False, timeout=300,
        env={**os.environ, "LC_ALL": "C"},
    )
    require(result.returncode == 0, f"{Path(cmd[0]).name} {cmd[1]} failed ({result.returncode}); no pass.")
    return result.stdout


def validate_archive_members(zipped):
    names = zipped.namelist()
    require(len(names) == len(set(names)), "Duplicate ZIP members.")
    return names


def native_report(path, temp, *, aab):
    inventory = []
    with ZipFile(path) as zipped:
        for name in sorted(validate_archive_members(zipped)):
            match = NATIVE.fullmatch(name)
            if not match or bool(match["module"]) != aab:
                continue
            library = temp / "library.so"  # Never extract an archive-supplied path.
            with zipped.open(name) as source, library.open("wb") as handle:
                shutil.copyfileobj(source, handle)
            segments = [line.split() for line in run("readelf", "-lW", str(library)).splitlines()
                        if line.strip().startswith("LOAD ")]
            require(segments, f"No ELF LOAD segments: {name}")
            if match["abi"] in {"arm64-v8a", "x86_64", "riscv64"}:
                require(
                    all(int(fields[-1], 16) >= 16384
                        and (int(fields[1], 16) - int(fields[2], 16)) % 16384 == 0
                        for fields in segments),
                    f"64-bit ELF LOAD is not 16 KB compatible: {name}",
                )
            inventory.append((name, sha(library), ",".join(fields[-1] for fields in segments)))
    return inventory


def examine(args, out):
    tool = lambda command, *options: run("java", "-jar", str(args.bundletool), command, *options)
    aab = str(args.aab)
    out.mkdir(mode=0o700)  # No overwrite; reports may contain configuration metadata.
    tool("validate", f"--bundle={aab}")
    signed = run("jarsigner", "-verify", "-verbose", f"{aab}")
    (out / "aab-jar-verification.txt").write_text(signed)
    require("jar verified." in signed and "unsigned entries" not in signed.lower(),
            "AAB JAR integrity did not verify for all signed content.")
    certs = run("keytool", "-printcert", "-jarfile", aab)
    signers = re.findall(r"(?m)^Signer #\d+:", certs)
    first_cert = re.search(r"(?im)^\s*SHA256:\s*([0-9a-f:]+)\s*$", certs)
    require(len(signers) == 1 and first_cert and digest(first_cert[1]) == args.upload_cert,
            "AAB signer does not match the independently supplied upload fingerprint.")
    (out / "aab-certificates.txt").write_text(certs)
    config = tool("dump", "config", f"--bundle={aab}")
    (out / "aab-config.txt").write_text(config)
    require("PAGE_ALIGNMENT_16K" in config, "AAB config does not advertise 16 KB page alignment.")
    with ZipFile(args.aab) as bundle:
        members = validate_archive_members(bundle)
        modules = sorted(match[1] for name in members
                         if (match := re.fullmatch(r"([A-Za-z0-9_]+)/manifest/AndroidManifest.xml", name)))
        sdk_markers = []
        for name in sorted(members):
            if (re.fullmatch(r"[A-Za-z0-9_]+/root/[A-Za-z0-9_.-]+\.properties", name)
                    and bundle.getinfo(name).file_size <= 8192):
                data = bundle.read(name).decode("utf-8", errors="replace")
                version = re.search(r"(?m)^version\s*=\s*([A-Za-z0-9.+_-]{1,100})\s*$", data)
                if version:
                    sdk_markers.append(f"{name}\t{version[1]}\n")
        (out / "aab-sdk-version-markers.tsv").write_text(
            "Packaged dependency markers only; reconcile with SBOM and native inspection.\n"
            + "".join(sdk_markers)
        )
    require("base" in modules, "AAB base manifest is missing.")
    for module in modules:
        manifest = tool("dump", "manifest", f"--bundle={aab}", f"--module={module}")
        (out / f"aab-manifest-{module}.xml").write_text(manifest)
        if module == "base":
            root = ET.fromstring(manifest)
            require(root.get("package") == APP_ID and
                    root.get(ANDROID + "versionCode") == args.version_code and
                    root.get(ANDROID + "versionName") == args.version_name,
                    "AAB package or version does not match the reviewed release.")
            application = root.find("application")
            require(application is not None and application.get(ANDROID + "debuggable") != "true",
                    "Unexpected debuggable AAB or missing application.")

    with tempfile.TemporaryDirectory(prefix="mort-android-readonly-") as tmp:
        temp = Path(tmp)
        aab_libs = native_report(args.aab, temp, aab=True)
        require(any(row[0] == "base/lib/arm64-v8a/libflutter.so" for row in aab_libs)
                and any(row[0] == "base/lib/arm64-v8a/libapp.so" for row in aab_libs),
                "AAB is missing ARM64 Flutter AOT libraries.")
        apk_rows, all_libs = [], [("AAB", *row) for row in aab_libs]
        bundle_libs = {(NATIVE.fullmatch(name)["abi"], NATIVE.fullmatch(name)["name"], binary_sha)
                       for name, binary_sha, _ in aab_libs}
        split_ids, required_types, delivered_types = set(), set(), set()
        arm = set()
        for i, apk in enumerate(args.apk, start=1):
            prefix = f"play-apk-{i:02d}"
            apk_sha = sha(apk)
            signature = run(str(args.tools / "apksigner"), "verify", "--print-certs", str(apk))
            found = re.findall(r"(?im)^Signer #\d+ certificate SHA-256 digest: ([0-9a-f:]+)$", signature)
            require([digest(fp) for fp in found] == [args.play_cert],
                    f"{prefix} does not match the independently supplied Play app-signing fingerprint.")
            (out / f"{prefix}-signature.txt").write_text(signature)
            run(str(args.tools / "zipalign"), "-c", "-P", "16", "4", str(apk))
            badging = run(str(args.tools / "aapt"), "dump", "badging", str(apk))
            package_line = badging.partition("\n")[0]
            pkg = re.match(r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']*)'", package_line)
            split = re.search(r"\bsplit='([^']+)'", package_line)
            split_id = split[1] if split else ""
            require(pkg and pkg[1] == APP_ID and pkg[2] == args.version_code and
                    (pkg[3] == args.version_name or (split_id and not pkg[3])) and
                    "application-debuggable" not in badging.splitlines(),
                    f"Wrong package/version or debuggable {prefix}.")
            require(split_id not in split_ids, "Duplicate split ID; inspect one delivered APK set at a time.")
            split_ids.add(split_id)
            (out / f"{prefix}-badging.txt").write_text(badging)
            for name, suffix in (("xmltree", "manifest"), ("permissions", "permissions")):
                extra = ["AndroidManifest.xml"] if name == "xmltree" else []
                text = run(str(args.tools / "aapt"), "dump", name, str(apk), *extra)
                (out / f"{prefix}-{suffix}.txt").write_text(text)
                if name == "xmltree":
                    for attribute, bucket in (
                        ("requiredSplitTypes", required_types), ("splitTypes", delivered_types),
                    ):
                        types = re.findall(rf'^\s*A: android:{attribute}\(0x[0-9a-f]+\)="([^"]*)"', text, re.M)
                        for group in types:
                            bucket.update(value for value in group.split(",") if value)
            for name, binary_sha, alignments in native_report(apk, temp, aab=False):
                all_libs.append((prefix, name, binary_sha, alignments))
                lib = NATIVE.fullmatch(name)
                require((lib["abi"], lib["name"], binary_sha) in bundle_libs,
                        f"Native binary {name} in {prefix} is absent or differs from the AAB.")
                if lib["abi"] == "arm64-v8a":
                    arm.add(lib["name"])
            apk_rows.append((prefix, apk_sha, package_line))
        require("" in split_ids and {"libflutter.so", "libapp.so"} <= arm,
                "No base APK or ARM64 Flutter AOT in the supplied Play set.")
        require(required_types <= delivered_types, "Missing required split types: "
                + ", ".join(sorted(required_types - delivered_types)))

    require(sha(args.aab) == args.aab_sha, "AAB SHA changed during inspection.")
    require(all(sha(apk) == row[1] for apk, row in zip(args.apk, apk_rows)),
            "An APK SHA changed during inspection.")
    (out / "native-loads.tsv").write_text(
        "input\tmember\tsha256\tELF_LOAD_alignments\n"
        + "".join("\t".join(row) + "\n" for row in all_libs)
    )
    (out / "static-checks.txt").write_text(
        f"Read-only static checks passed. AAB SHA-256: {args.aab_sha}\n"
        f"Upload fingerprint: {args.upload_cert}\nPlay APK signer fingerprint: {args.play_cert}\n"
        "Owner must independently record Play Console download provenance, track, and delivered configurations.\n"
        "Use base and feature XML to determine effective permissions; split-only badging can imply permissions.\n"
        "Review manifests and SDK inventory against approved store declarations and provider config.\n"
        "No install, runtime, network behavior, release approval, or Play Console access was verified.\n"
        + "".join("\t".join(row) + "\n" for row in apk_rows)
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("aab", "bundletool", "tools", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--apk", action="append", type=Path, required=True,
                        help="Original Play-generated APK path (repeat for all splits of one delivery set).")
    for name in ("aab-sha", "upload-cert", "play-cert", "version-code", "version-name"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    try:
        os.umask(0o077)
        args.aab_sha, args.upload_cert, args.play_cert = map(
            digest, (args.aab_sha, args.upload_cert, args.play_cert))
        require(re.fullmatch(r"[0-9]+", args.version_code) and
                re.fullmatch(r"[0-9][A-Za-z0-9.+-]*", args.version_name), "Invalid reviewed release version.")
        args.aab = args.aab.resolve(strict=True)
        args.bundletool = args.bundletool.resolve(strict=True)
        args.apk = [apk.resolve(strict=True) for apk in args.apk]
        args.tools = args.tools.resolve(strict=True)
        require(len(set(args.apk)) == len(args.apk), "List each APK once.")
        require(sha(args.aab) == args.aab_sha, "Input AAB differs from the recorded SHA-256.")
        require(sha(args.bundletool) == BUNDLETOOL_SHA, "Expected pinned bundletool 1.18.3.")
        examine(args, args.out)
        print(f"STATIC CHECKS ONLY: {args.out / 'static-checks.txt'}")
    except (OSError, ValueError, subprocess.TimeoutExpired, ET.ParseError) as error:
        print(f"NOT VERIFIED: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
