"""Prepare local iOS Firebase and OAuth configuration before xcodegen."""
import argparse
import pathlib
import plistlib
import shutil
import re

parser = argparse.ArgumentParser()
parser.add_argument("firebase_plist", type=pathlib.Path)
args = parser.parse_args()
with args.firebase_plist.open("rb") as f:
    config = plistlib.load(f)
if config.get("BUNDLE_ID") != "fi.vladi.tarkastuscloud":
    raise SystemExit("Firebase iOS Bundle ID must be fi.vladi.tarkastuscloud")
for key in ("GOOGLE_APP_ID", "API_KEY", "PROJECT_ID", "CLIENT_ID", "REVERSED_CLIENT_ID"):
    if not isinstance(config.get(key), str) or not config[key].strip():
        raise SystemExit("Missing Firebase configuration: " + key)
if config["PROJECT_ID"] != "tarkastus-cloud" or config["GOOGLE_APP_ID"] != "1:425303240003:ios:2e98b16ad9531d5e4d93f6":
    raise SystemExit("Unexpected Firebase iOS app")
scheme = config["REVERSED_CLIENT_ID"]
if scheme != "com.googleusercontent.apps.425303240003-mt8e9c7vvi6v3qbr75lqrvfhpuniaaa3":
    raise SystemExit("Unexpected Google OAuth client")
if not re.fullmatch(r"[A-Za-z][A-Za-z0-9.+-]*", scheme) or scheme != ".".join(reversed(config["CLIENT_ID"].split("."))):
    raise SystemExit("Invalid reversed Google client ID")
root = pathlib.Path(__file__).resolve().parents[1]
target = root / "TarkastusCloud/GoogleService-Info.plist"
if args.firebase_plist.resolve() != target.resolve():
    shutil.copyfile(args.firebase_plist, target)
# XcodeGen generates the explicit Info.plist URL scheme from this property.
override = root / "project.local.yml"
override.write_text("include: [project.yml]\ntargets:\n  TarkastusCloud:\n    settings:\n      base:\n        GENERATE_INFOPLIST_FILE: NO\n    info:\n      path: Generated/Info.plist\n      properties:\n        CFBundleURLTypes:\n          - CFBundleURLSchemes: [" + scheme + "]\n        NSFaceIDUsageDescription: Unlock your inspection reports.\n        NSCameraUsageDescription: Take inspection photos for reports.\n        CFBundleDisplayName: Tarkastus Cloud\n        UILaunchScreen: {}\n")
print("Configuration prepared. Run xcodegen generate --spec project.local.yml")
