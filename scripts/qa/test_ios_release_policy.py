import unittest
from datetime import datetime, timezone
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import stat
from tempfile import TemporaryDirectory
from zipfile import ZipFile, ZipInfo


spec = spec_from_file_location("policy", Path(__file__).with_name("verify-ios-release.py"))
policy = module_from_spec(spec)
spec.loader.exec_module(policy)


class IOSReleasePolicyTest(unittest.TestCase):
    def setUp(self):
        self.team = "FIXTURE123"
        self.now = datetime(2026, 11, 22, tzinfo=timezone.utc)
        self.info = {
            "CFBundleIdentifier": "com.mortapp.mobile",
            "CFBundleShortVersionString": "0.9.16",
            "CFBundleVersion": "111",
            "MinimumOSVersion": "15.0",
            "CFBundleURLTypes": [{"CFBundleURLSchemes": ["com.mortapp.mobile"]}],
            "FirebaseMessagingAutoInitEnabled": False,
            "GADDelayAppMeasurementInit": True,
        }
        self.signed = {
            "application-identifier": f"{self.team}.com.mortapp.mobile",
            "get-task-allow": False,
            "com.apple.developer.team-identifier": self.team,
            "aps-environment": "production",
            "com.apple.developer.associated-domains": ["applinks:example.invalid"],
        }
        self.profile = {
            "TeamIdentifier": [self.team],
            "ExpirationDate": datetime(2027, 1, 1),
            "Entitlements": dict(self.signed),
        }

    def evaluate(self, mode="app-store", push=True, domains=("applinks:example.invalid",)):
        policy.evaluate(self.info, self.signed, self.profile, self.team, mode, push, domains, self.now)

    def test_distribution_and_ad_hoc_scopes(self):
        self.evaluate()
        self.profile["ProvisionedDevices"] = ["fixture-only"]
        self.evaluate(mode="ad-hoc")
        with self.assertRaises(policy.VerificationError):
            self.evaluate()

    def test_expired_wrong_team_or_debug_signature_denied(self):
        for target, key, value in [
            (self.profile, "ExpirationDate", datetime(2025, 1, 1)),
            (self.profile, "TeamIdentifier", ["WRONGTEAM1"]),
            (self.signed, "get-task-allow", True),
            (self.signed, "application-identifier", "com.example.other"),
        ]:
            with self.subTest(field=key):
                before = target[key]
                target[key] = value
                with self.assertRaises(policy.VerificationError):
                    self.evaluate()
                target[key] = before

    def test_mismatched_push_domain_or_oauth_is_denied(self):
        self.signed["aps-environment"] = "development"
        with self.assertRaises(policy.VerificationError):
            self.evaluate()
        del self.signed["aps-environment"]
        del self.profile["Entitlements"]["aps-environment"]
        self.evaluate(push=False)
        with self.assertRaises(policy.VerificationError):
            self.evaluate(push=False, domains=())
        self.info["CFBundleURLTypes"] = []
        with self.assertRaises(policy.VerificationError):
            self.evaluate(push=False)

    def test_mismatched_export_cannot_pass(self):
        archive = {"binary_uuid": b"abc", "privacy_manifest_sha256": "abc"}
        policy.verify_same_build(archive, dict(archive))
        for key in archive:
            with self.subTest(key=key), self.assertRaises(policy.VerificationError):
                policy.verify_same_build(archive, {**archive, key: "different"})
        sample = b"UUID: 39DA8238-7CF4-4262-9DD0-D67CA9356D60 (arm64) Runner\n"
        self.assertEqual(policy.code_identity(sample), b"39da8238-7cf4-4262-9dd0-d67ca9356d60")
        with self.assertRaises(policy.VerificationError):
            policy.code_identity(sample.replace(b"arm64", b"x86_64"))

    def test_unpack_ipa_preserves_input_and_only_extracts_payload(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            ipa = root / "fixture.ipa"
            executable = ZipInfo("Payload/Runner.app/Runner")
            executable.external_attr = (stat.S_IFREG | 0o755) << 16
            with ZipFile(ipa, "w") as fixture:
                fixture.writestr(executable, b"binary fixture")
                fixture.writestr("SwiftSupport/ignored", b"not the app")
            digest = policy.sha256(ipa)
            app = policy.unpack_ipa(ipa, root / "extracted")
            self.assertEqual((app / "Runner").read_bytes(), b"binary fixture")
            self.assertTrue((app / "Runner").stat().st_mode & 0o100)
            self.assertFalse((root / "extracted" / "SwiftSupport").exists())
            self.assertEqual(policy.sha256(ipa), digest)

    def test_rejects_ambiguous_and_special_ipa_entries(self):
        link = ZipInfo("Payload/Runner.app/Link")
        link.external_attr = (stat.S_IFLNK | 0o777) << 16
        for invalid in (
            "Payload/Runner.app/../../escaped",
            "/Payload/Runner.app/escaped",
            "Payload\\Runner.app\\escaped",
            "Payload//Runner.app/escaped",
            "Payload/Runner.app/info.plist",
            "Payload/Other.app/Info.plist",
            link,
        ):
            with self.subTest(entry=invalid), TemporaryDirectory() as directory:
                root = Path(directory)
                ipa = root / "bad.ipa"
                with ZipFile(ipa, "w") as fixture:
                    fixture.writestr("Payload/Runner.app/Info.plist", b"fixture")
                    fixture.writestr(invalid, b"fixture")
                with self.assertRaises(policy.VerificationError):
                    policy.unpack_ipa(ipa, root / "extracted")
                self.assertFalse((root / "extracted").exists())


if __name__ == "__main__":
    unittest.main()
