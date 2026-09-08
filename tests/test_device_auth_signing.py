"""Synthetic signing metadata/tool doubles; never uses a device or real credentials."""
import copy
import datetime as dt
import importlib.util
import io
import json
import plistlib
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location("device_auth_signing", Path(__file__).resolve().parents[1] / "scripts/device_auth_signing.py")
gate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gate)
NOW = dt.datetime(2026, 9, 8, tzinfo=dt.timezone.utc)
SYNTHETIC_DEVICE = "0" * 40  # Deliberately fake; no personal device IDs in source.


def fixture():
    info = {"CFBundleIdentifier": gate.EXPECTED_BUNDLE_ID, "CFBundleSupportedPlatforms": ["iPhoneOS"],
            "CFBundleURLTypes": [{"CFBundleURLSchemes": ["matths"]}]}
    ent = {"application-identifier": gate.EXPECTED_TEAM_ID + "." + gate.EXPECTED_BUNDLE_ID,
           "com.apple.developer.team-identifier": gate.EXPECTED_TEAM_ID,
           "com.apple.developer.applesignin": ["Default"], "get-task-allow": True}
    profile = {"TeamIdentifier": [gate.EXPECTED_TEAM_ID], "ApplicationIdentifierPrefix": [gate.EXPECTED_TEAM_ID],
               "Entitlements": copy.deepcopy(ent), "CreationDate": (NOW - dt.timedelta(days=1)).replace(tzinfo=None),
               "ExpirationDate": (NOW + dt.timedelta(days=365)).replace(tzinfo=None),
               "DeveloperCertificates": [b"synthetic-signer"], "ProvisionedDevices": [SYNTHETIC_DEVICE]}
    signature = {"Identifier": gate.EXPECTED_BUNDLE_ID, "TeamIdentifier": gate.EXPECTED_TEAM_ID}
    return [info, ent, profile, signature, b"synthetic-signer"]


class MetadataTests(unittest.TestCase):
    def check_failure(self, data, code, **kwargs):
        with self.assertRaises(gate.GateFailure) as caught:
            gate.validate_metadata(*data, now=NOW, **kwargs)
        self.assertEqual(caught.exception.code, code)
        self.assertNotIn(SYNTHETIC_DEVICE, str(caught.exception))

    def test_development_and_optional_device(self):
        result = gate.validate_metadata(*fixture(), now=NOW)
        self.assertEqual((result["result"], result["profileKind"], result["deviceMembership"]), ("PASS", "development", "not_requested"))
        checked = gate.validate_metadata(*fixture(), now=NOW, device_udid=SYNTHETIC_DEVICE)
        self.assertEqual(checked["deviceMembership"], "matched")
        self.assertNotIn(SYNTHETIC_DEVICE, json.dumps(checked))

    def test_distribution_without_implicit_device_check(self):
        data = fixture(); data[1]["get-task-allow"] = False; data[2]["Entitlements"]["get-task-allow"] = False
        data[2].pop("ProvisionedDevices")
        result = gate.validate_metadata(*data, now=NOW)
        self.assertEqual(result["profileKind"], "distribution")
        self.check_failure(data, "DEVICE_NOT_IN_PROFILE", device_udid=SYNTHETIC_DEVICE)

    def test_ad_hoc_and_all_devices(self):
        data = fixture(); data[1]["get-task-allow"] = False; data[2]["Entitlements"]["get-task-allow"] = False
        self.assertEqual(gate.validate_metadata(*data, now=NOW)["profileKind"], "ad-hoc")
        data[2]["ProvisionsAllDevices"] = True
        self.assertEqual(gate.validate_metadata(*data, now=NOW, device_udid=SYNTHETIC_DEVICE)["deviceMembership"], "all_devices")

    def test_legacy_app_prefix_is_not_confused_with_team(self):
        data = fixture(); prefix = "LEGACY0001"
        data[1]["application-identifier"] = prefix + "." + gate.EXPECTED_BUNDLE_ID
        data[2]["Entitlements"]["application-identifier"] = data[1]["application-identifier"]
        data[2]["ApplicationIdentifierPrefix"] = [prefix]
        self.assertEqual(gate.validate_metadata(*data, now=NOW)["result"], "PASS")

    def test_qa_bundle(self):
        data = fixture(); data[0]["CFBundleIdentifier"] += ".uiqa"
        self.check_failure(data, "BUNDLE_ID_MISMATCH")

    def test_wrong_or_qa_callback(self):
        for schemes, code in [(["matths-uiqa"], "CALLBACK_SCHEME_MISSING"), (["matths", "matths-uiqa"], "QA_CALLBACK_SCHEME")]:
            with self.subTest(schemes=schemes):
                data = fixture(); data[0]["CFBundleURLTypes"][0]["CFBundleURLSchemes"] = schemes
                self.check_failure(data, code)

    def test_simulator(self):
        data = fixture(); data[0]["CFBundleSupportedPlatforms"] = ["iPhoneSimulator"]
        self.check_failure(data, "DEVICE_PLATFORM_REQUIRED")

    def test_missing_signed_apple(self):
        for value in (None, [], ["Other"], "Default"):
            with self.subTest(value=value):
                data = fixture(); data[1]["com.apple.developer.applesignin"] = value
                self.check_failure(data, "APPLE_ENTITLEMENT_MISSING")

    def test_missing_profile_apple(self):
        data = fixture(); data[2]["Entitlements"].pop("com.apple.developer.applesignin")
        self.check_failure(data, "PROFILE_APPLE_ENTITLEMENT_MISSING")

    def test_signature_identity_and_teams(self):
        for dictionary, key, code in [(3, "Identifier", "SIGNATURE_IDENTIFIER_MISMATCH"), (3, "TeamIdentifier", "SIGNATURE_TEAM_MISMATCH"), (1, "com.apple.developer.team-identifier", "PROFILE_TEAM_MISMATCH")]:
            with self.subTest(key=key):
                data = fixture(); data[dictionary][key] = "INVALID"
                self.check_failure(data, code)
        data = fixture(); data[2]["TeamIdentifier"] = ["WRONGTEAM0"]
        self.check_failure(data, "PROFILE_TEAM_MISMATCH")

    def test_wildcard_and_mismatched_identifiers(self):
        data = fixture(); data[2]["Entitlements"]["application-identifier"] = gate.EXPECTED_TEAM_ID + ".*"
        self.check_failure(data, "WILDCARD_PROFILE")
        data = fixture(); data[2]["Entitlements"]["application-identifier"] += ".uiqa"
        self.check_failure(data, "APPLICATION_IDENTIFIER_MISMATCH")
        data = fixture(); data[2]["ApplicationIdentifierPrefix"] = ["WRONGTEAM0"]
        self.check_failure(data, "APPLICATION_PREFIX_MISMATCH")

    def test_expired_future_or_malformed_profile(self):
        for field, value, code in [("ExpirationDate", NOW, "PROFILE_EXPIRED_OR_NOT_YET_VALID"), ("CreationDate", NOW + dt.timedelta(seconds=1), "PROFILE_EXPIRED_OR_NOT_YET_VALID"), ("ExpirationDate", "invalid", "PROFILE_DATE_INVALID")]:
            with self.subTest(field=field, value=value):
                data = fixture(); data[2][field] = value
                self.check_failure(data, code)

    def test_leaf_certificate_and_debug_permission(self):
        data = fixture(); data[4] = b"another-signer"
        self.check_failure(data, "SIGNER_NOT_IN_PROFILE")
        data = fixture(); data[2]["Entitlements"]["get-task-allow"] = False
        self.check_failure(data, "DEBUG_ENTITLEMENT_NOT_ALLOWED")

    def test_explicit_device_does_not_leak(self):
        data = fixture(); data[2]["ProvisionedDevices"] = []
        self.check_failure(data, "DEVICE_NOT_IN_PROFILE", device_udid=SYNTHETIC_DEVICE)
        self.check_failure(fixture(), "DEVICE_ARGUMENT_INVALID", device_udid="invalid")


class ReadOnlyToolBoundaryTests(unittest.TestCase):
    def test_malformed_command_does_not_echo_device_identifier(self):
        errors = io.StringIO()
        with patch.object(sys, "argv", ["gate", "app", "--unknown-device", SYNTHETIC_DEVICE]), redirect_stderr(errors):
            with self.assertRaises(SystemExit) as caught:
                gate.main()
        self.assertEqual(caught.exception.code, 2)
        self.assertEqual(json.loads(errors.getvalue())["code"], "INVALID_ARGUMENTS")
        self.assertNotIn(SYNTHETIC_DEVICE, errors.getvalue())

    def test_actual_inspector_uses_strict_tools_and_preserves_bundle(self):
        data = fixture(); calls = []
        with tempfile.TemporaryDirectory(prefix="matths-signing-test-") as temporary:
            app = Path(temporary) / "Matths.app"; app.mkdir()
            (app / "Info.plist").write_bytes(plistlib.dumps(data[0]))
            (app / "embedded.mobileprovision").write_bytes(b"synthetic-cms")
            before = {p.name: p.read_bytes() for p in app.iterdir()}
            def run(arguments, **kwargs):
                calls.append(arguments)
                self.assertEqual(kwargs["timeout"], 20)
                if "--verify" in arguments and "-R" in arguments:
                    # Actual codesign interprets a following separate token as
                    # a filename. This reproduces the false rejection found on
                    # the real signed production-identity build 19 artifact.
                    return subprocess.CompletedProcess(arguments, 1, b"", b"invalid requirement specification")
                if "--extract-certificates" in arguments:
                    return subprocess.CompletedProcess(arguments, 1, b"", b"prefix: No such file or directory")
                output, errors = b"", b""
                if "--entitlements" in arguments: output = plistlib.dumps(data[1])
                elif "--verbose=4" in arguments: errors = f"Identifier={gate.EXPECTED_BUNDLE_ID}\nTeamIdentifier={gate.EXPECTED_TEAM_ID}\n".encode()
                elif "cms" in arguments: output = plistlib.dumps(data[2])
                elif any(value.startswith("--extract-certificates=") for value in arguments):
                    prefix = next(value.split("=", 1)[1] for value in arguments if value.startswith("--extract-certificates="))
                    Path(prefix + "0").write_bytes(data[4])
                return subprocess.CompletedProcess(arguments, 0, output, errors)
            with patch.object(gate.subprocess, "run", side_effect=run):
                self.assertEqual(gate.inspect_app(app)["result"], "PASS")
            self.assertEqual({p.name: p.read_bytes() for p in app.iterdir()}, before)
            verify = calls[0]
            for flag in ("--verify", "--deep", "--strict", "--all-architectures"):
                self.assertIn(flag, verify)
            requirement_args = [value for value in verify if value.startswith("-R=")]
            self.assertEqual(len(requirement_args), 1)
            self.assertEqual(requirement_args[0], '-R=anchor apple generic and identifier "kr.matths.app" and certificate leaf[subject.OU] = "64U874RU4D"')
            self.assertNotIn("-R", verify, "separate -R argument is a filename, not an inline requirement")
            self.assertTrue(any(any(value.startswith("--extract-certificates=") for value in call) for call in calls))
            self.assertTrue(all("--extract-certificates" not in call for call in calls), "optional prefix must not be mistaken for another code path")
            self.assertTrue(all(call[0] in ("/usr/bin/codesign", "/usr/bin/security") for call in calls))
            self.assertTrue(all("--sign" not in call and "-s" not in call for call in calls))

    def test_codesign_failure_is_not_accepted_or_printed(self):
        data = fixture()
        with tempfile.TemporaryDirectory(prefix="matths-signing-test-") as temporary:
            app = Path(temporary) / "Matths.app"; app.mkdir()
            (app / "Info.plist").write_bytes(plistlib.dumps(data[0])); (app / "embedded.mobileprovision").write_bytes(b"cms")
            output = io.StringIO(); errors = io.StringIO()
            failed = subprocess.CompletedProcess([], 1, b"", ("private-output-" + SYNTHETIC_DEVICE).encode())
            with patch.object(gate.subprocess, "run", return_value=failed), patch.object(sys, "argv", ["gate", str(app), "--device-udid", SYNTHETIC_DEVICE]), redirect_stdout(output), redirect_stderr(errors):
                self.assertEqual(gate.main(), 1)
            self.assertEqual(json.loads(errors.getvalue())["code"], "STRICT_SIGNATURE_FAILED")
            self.assertNotIn(SYNTHETIC_DEVICE, errors.getvalue() + output.getvalue())
            self.assertNotIn("private-output", errors.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
