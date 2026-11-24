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
scheme = config["REVERSED_CLIENT_ID"]
if not re.fullmatch(r"[A-Za-z][A-Za-z0-9.+-]*", scheme) or scheme != ".".join(reversed(config["CLIENT_ID"].split("."))):
    raise SystemExit("Invalid reversed Google client ID")
root = pathlib.Path(__file__).resolve().parents[1]
target = root / "TarkastusCloud/GoogleService-Info.plist"
if args.firebase_plist.resolve() != target.resolve():
    shutil.copyfile(args.firebase_plist, target)
project = root / "project.yml"
text = project.read_text()
text = re.sub(r"(?m)^        INFOPLIST_KEY_CFBundleURLTypes:.*\n", "", text)
# XcodeGen generates the explicit Info.plist URL scheme from this property.
override = root / "project.local.yml"
override.write_text("include: [project.yml]\ntargets:\n  TarkastusCloud:\n    info:\n      path: Generated/Info.plist\n      properties:\n        CFBundleURLTypes:\n          - CFBundleURLSchemes: [" + scheme + "]\n        NSFaceIDUsageDescription: Unlock your inspection reports.\n        NSCameraUsageDescription: Take inspection photos for reports.\n        CFBundleDisplayName: Tarkastus Cloud\n        UILaunchScreen: {}\n")
print("Configuration prepared. Run xcodegen generate --spec project.local.yml")
