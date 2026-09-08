"""Read-only device-auth artifact gate; metadata validator is independently testable."""
import argparse
import datetime as dt
import json
import plistlib
import re
import subprocess
import sys
import tempfile
from pathlib import Path

EXPECTED_BUNDLE_ID = "kr.matths.app"
EXPECTED_TEAM_ID = "64U874RU4D"  # Public development team in Matths.xcodeproj.


class GateFailure(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


def require(condition, code, message):
    if not condition:
        raise GateFailure(code, message)


def utc(value):
    require(isinstance(value, dt.datetime), "PROFILE_DATE_INVALID", "프로파일의 유효기간을 확인할 수 없습니다.")
    return value.replace(tzinfo=dt.timezone.utc) if value.tzinfo is None else value.astimezone(dt.timezone.utc)


def validate_metadata(info, entitlements, profile, signature, leaf_certificate, *, now=None, device_udid=None):
    """No subprocess, network or filesystem. Never includes private values in failures."""
    now = utc(now or dt.datetime.now(dt.timezone.utc))
    for value in (info, entitlements, profile, signature):
        require(isinstance(value, dict), "METADATA_INVALID", "서명 메타데이터 형식이 올바르지 않습니다.")
    require(info.get("CFBundleIdentifier") == EXPECTED_BUNDLE_ID,
            "BUNDLE_ID_MISMATCH", "정식 kr.matths.app이 아닙니다. QA 복제본으로 실기 로그인을 검증할 수 없습니다.")
    require(info.get("CFBundleSupportedPlatforms") == ["iPhoneOS"],
            "DEVICE_PLATFORM_REQUIRED", "iPhoneOS 실기용 앱이 아닙니다.")
    schemes = set()
    for row in info.get("CFBundleURLTypes", []):
        if isinstance(row, dict):
            schemes.update(value.lower() for value in row.get("CFBundleURLSchemes", []) if isinstance(value, str))
    require("matths" in schemes, "CALLBACK_SCHEME_MISSING", "정식 matths 로그인 복귀 scheme이 없습니다.")
    require("matths-uiqa" not in schemes, "QA_CALLBACK_SCHEME", "QA 로그인 복귀 scheme이 남아 있습니다.")
    require(entitlements.get("com.apple.developer.applesignin") == ["Default"],
            "APPLE_ENTITLEMENT_MISSING", "실제 앱 서명에 Apple 로그인 Default 권한이 없습니다.")
    profile_entitlements = profile.get("Entitlements")
    require(isinstance(profile_entitlements, dict), "PROFILE_ENTITLEMENTS_INVALID", "프로파일 권한을 읽을 수 없습니다.")
    require(profile_entitlements.get("com.apple.developer.applesignin") == ["Default"],
            "PROFILE_APPLE_ENTITLEMENT_MISSING", "프로파일이 Apple 로그인 Default 권한을 허용하지 않습니다.")
    require(signature.get("Identifier") == EXPECTED_BUNDLE_ID,
            "SIGNATURE_IDENTIFIER_MISMATCH", "서명 식별자와 정식 앱 식별자가 다릅니다.")
    require(signature.get("TeamIdentifier") == EXPECTED_TEAM_ID,
            "SIGNATURE_TEAM_MISMATCH", "정식 개발 팀으로 서명되지 않았습니다.")
    require(profile.get("TeamIdentifier") == [EXPECTED_TEAM_ID]
            and profile_entitlements.get("com.apple.developer.team-identifier") == EXPECTED_TEAM_ID
            and entitlements.get("com.apple.developer.team-identifier") == EXPECTED_TEAM_ID,
            "PROFILE_TEAM_MISMATCH", "앱·프로파일·서명의 개발 팀이 일치하지 않습니다.")
    app_identifier = entitlements.get("application-identifier")
    profile_identifier = profile_entitlements.get("application-identifier")
    require(isinstance(app_identifier, str) and isinstance(profile_identifier, str),
            "APPLICATION_IDENTIFIER_MISSING", "앱 또는 프로파일 application-identifier가 없습니다.")
    require("*" not in app_identifier and "*" not in profile_identifier,
            "WILDCARD_PROFILE", "와일드카드 프로파일은 네이티브 Apple 로그인 검증에 사용할 수 없습니다.")
    require(app_identifier == profile_identifier and app_identifier.endswith("." + EXPECTED_BUNDLE_ID),
            "APPLICATION_IDENTIFIER_MISMATCH", "앱과 프로파일의 application-identifier가 일치하지 않습니다.")
    prefix = app_identifier[:-(len(EXPECTED_BUNDLE_ID) + 1)]
    require(re.fullmatch(r"[A-Z0-9]{10}", prefix) and prefix in (profile.get("ApplicationIdentifierPrefix") or []),
            "APPLICATION_PREFIX_MISMATCH", "프로파일의 App ID prefix와 실제 서명 식별자가 다릅니다.")
    expiration = utc(profile.get("ExpirationDate"))
    creation = utc(profile.get("CreationDate"))
    require(creation <= now < expiration, "PROFILE_EXPIRED_OR_NOT_YET_VALID", "프로파일이 만료됐거나 아직 유효하지 않습니다.")
    certificates = profile.get("DeveloperCertificates")
    require(isinstance(leaf_certificate, bytes) and bool(leaf_certificate)
            and isinstance(certificates, list) and leaf_certificate in certificates,
            "SIGNER_NOT_IN_PROFILE", "실제 서명 인증서가 해당 프로파일의 허용 인증서와 다릅니다.")
    signed_debug = entitlements.get("get-task-allow", False)
    allowed_debug = profile_entitlements.get("get-task-allow", False)
    require(isinstance(signed_debug, bool) and isinstance(allowed_debug, bool)
            and (not signed_debug or allowed_debug),
            "DEBUG_ENTITLEMENT_NOT_ALLOWED", "앱의 디버깅 권한을 프로파일이 허용하지 않습니다.")
    device_status = "not_requested"
    if device_udid is not None:
        require(isinstance(device_udid, str) and re.fullmatch(r"[A-Fa-f0-9-]{20,80}", device_udid),
                "DEVICE_ARGUMENT_INVALID", "기기 식별자 인자 형식이 올바르지 않습니다.")
        if profile.get("ProvisionsAllDevices") is True:
            device_status = "all_devices"
        else:
            devices = profile.get("ProvisionedDevices")
            require(isinstance(devices, list) and any(isinstance(value, str) and value.lower() == device_udid.lower() for value in devices),
                    "DEVICE_NOT_IN_PROFILE", "명시한 기기가 프로파일에 등록되어 있지 않습니다.")
            device_status = "matched"
    return {
        "result": "PASS", "purpose": "production-identity device OAuth signing preflight",
        "bundleIdentifier": EXPECTED_BUNDLE_ID, "teamIdentifier": EXPECTED_TEAM_ID,
        "callbackScheme": "matths", "nativeAppleEntitlement": "Default",
        "profileKind": "development" if allowed_debug else "all-devices" if profile.get("ProvisionsAllDevices") is True else "ad-hoc" if profile.get("ProvisionedDevices") else "distribution",
        "profileExpiresAt": expiration.isoformat(), "deviceMembership": device_status,
        "profileScope": "main application; nested code signatures are verified, per-extension provisioning is not separately inspected",
        "scopeLimit": "Not a completed OAuth login, server audience check, install, or App Store submission verdict",
    }


def command(arguments, code, message):
    try:
        result = subprocess.run(arguments, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20, check=False)
    except (OSError, subprocess.TimeoutExpired):
        raise GateFailure(code, message) from None
    require(result.returncode == 0, code, message)
    return result


def plist_bytes(value, code):
    try:
        decoded = plistlib.loads(value)
    except (ValueError, TypeError, plistlib.InvalidFileException):
        raise GateFailure(code, "서명 또는 프로파일 plist를 읽을 수 없습니다.") from None
    require(isinstance(decoded, dict), code, "서명 또는 프로파일 plist 형식이 올바르지 않습니다.")
    return decoded


def inspect_app(app, *, device_udid=None):
    app = Path(app)
    require(app.is_dir() and app.suffix == ".app" and not app.is_symlink(), "APP_PATH_INVALID", "검사할 실제 .app 디렉터리를 지정해 주세요.")
    app = app.resolve()
    info_path = app / "Info.plist"
    profile_path = app / "embedded.mobileprovision"
    for path in (info_path, profile_path):
        require(path.is_file() and not path.is_symlink() and 0 < path.stat().st_size <= 4 * 1024 * 1024,
                "BUNDLE_METADATA_MISSING", "실기 앱의 Info.plist 또는 embedded.mobileprovision을 확인할 수 없습니다.")
    info = plist_bytes(info_path.read_bytes(), "INFO_PLIST_INVALID")
    require(info.get("CFBundleIdentifier") == EXPECTED_BUNDLE_ID,
            "BUNDLE_ID_MISMATCH", "정식 kr.matths.app이 아닙니다. QA 복제본으로 실기 로그인을 검증할 수 없습니다.")
    requirement = f'anchor apple generic and identifier "{EXPECTED_BUNDLE_ID}" and certificate leaf[subject.OU] = "{EXPECTED_TEAM_ID}"'
    # -R <value> reads a requirement FILE; -R=<expression> parses inline text.
    # Passing the expression as a separate token rejects every valid app before
    # checking its signature. Keep the exact strong requirement, not a fallback.
    command(["/usr/bin/codesign", "--verify", "--deep", "--strict", "--all-architectures", "--verbose=2", "-R=" + requirement, str(app)],
            "STRICT_SIGNATURE_FAILED", "정식 Apple 개발 팀 서명 또는 앱/확장 리소스의 엄격 검증에 실패했습니다.")
    entitlement_result = command(["/usr/bin/codesign", "--display", "--entitlements", ":-", str(app)],
                                 "SIGNED_ENTITLEMENTS_FAILED", "실제 앱 서명의 권한을 추출하지 못했습니다.")
    entitlements = plist_bytes(entitlement_result.stdout, "SIGNED_ENTITLEMENTS_INVALID")
    details = command(["/usr/bin/codesign", "--display", "--verbose=4", str(app)],
                      "SIGNATURE_METADATA_FAILED", "서명 식별자를 읽지 못했습니다.")
    signature = {}
    for line in (details.stdout + details.stderr).decode("utf-8", errors="replace").splitlines():
        if line.startswith(("Identifier=", "TeamIdentifier=")):
            key, value = line.split("=", 1)
            signature[key] = value.strip()
    profile_result = command(["/usr/bin/security", "cms", "-D", "-i", str(profile_path)],
                             "PROFILE_CMS_FAILED", "프로비저닝 프로파일 CMS를 해석하지 못했습니다.")
    profile = plist_bytes(profile_result.stdout, "PROFILE_PLIST_INVALID")
    with tempfile.TemporaryDirectory(prefix="matths-auth-signing-") as temporary:
        # Only public certificate material is extracted into this private temp
        # directory. The .app and profile are never modified or re-signed.
        prefix = str(Path(temporary) / "signer-")
        # This long option has an optional argument, so its prefix must also be
        # attached with '='; a separate token is treated as another code path.
        command(["/usr/bin/codesign", "--display", "--extract-certificates=" + prefix, str(app)],
                "SIGNER_EXTRACTION_FAILED", "서명 인증서를 읽지 못했습니다.")
        leaf_path = Path(prefix + "0")
        require(leaf_path.is_file(), "SIGNER_CERTIFICATE_MISSING", "실제 개발자 서명 인증서가 없습니다.")
        leaf = leaf_path.read_bytes()
    return validate_metadata(info, entitlements, profile, signature, leaf, device_udid=device_udid)


class SafeArgumentParser(argparse.ArgumentParser):
    def error(self, _message):
        # argparse normally echoes unknown argument values, which could include
        # an accidentally misplaced device ID. Keep even usage failures private.
        print(json.dumps({"result": "FAIL", "code": "INVALID_ARGUMENTS", "message": "사용법: verify-device-auth-signing.sh <app> [--device-udid <기기 식별자>]"}, ensure_ascii=False), file=sys.stderr)
        self.exit(2)


def main():
    parser = SafeArgumentParser(prog="verify-device-auth-signing.sh", description="Read-only production-identity device OAuth signing gate; no install or login.")
    parser.add_argument("app", help="Path to the signed .app artifact")
    parser.add_argument("--device-udid", default=None, help="Optional explicit device membership check; the value is never printed")
    args = parser.parse_args()
    try:
        print(json.dumps(inspect_app(args.app, device_udid=args.device_udid), ensure_ascii=False))
        return 0
    except GateFailure as error:
        print(json.dumps({"result": "FAIL", "code": error.code, "message": str(error)}, ensure_ascii=False), file=sys.stderr)
        return 1
    except Exception:
        print(json.dumps({"result": "FAIL", "code": "GATE_READ_ERROR", "message": "앱 서명을 안전하게 읽지 못했습니다."}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
