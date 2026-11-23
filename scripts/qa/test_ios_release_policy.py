import unittest
from datetime import datetime, timezone
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path


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


if __name__ == "__main__":
    unittest.main()
