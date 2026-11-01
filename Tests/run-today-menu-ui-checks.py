#!/usr/bin/env python3
"""Run isolated UI checks on the existing iPhone 18 Pro simulator.

Usage: python3 Tests/run-today-menu-ui-checks.py
       python3 Tests/run-today-menu-ui-checks.py --build-only
       python3 Tests/run-today-menu-ui-checks.py --jump
Results and build logs are retained in the printed temporary directory.
"""
import argparse
import json
import plistlib
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--build-only", action="store_true", help="Compile UI tests without booting a simulator")
parser.add_argument("--jump", action="store_true", help="Use isolated jump fixtures and jump UI checks")
parser.add_argument("--device", default="F352495D-B57F-4408-ACA7-0BCE3C577FFF")
parser.add_argument("--only-testing", action="append", default=[], help="Optional XCTest class or method to run (repeatable)")
arguments = parser.parse_args()
work = Path(tempfile.mkdtemp(prefix="CookJotMenuUI-", dir="/private/tmp"))
print(f"UI test artifacts: {work}", flush=True)


def run(arguments, log=None, timeout=300):
    if log:
        with (work / log).open("w") as output:
            subprocess.run(arguments, check=True, stdout=output, stderr=subprocess.STDOUT, timeout=timeout)
    else:
        subprocess.run(arguments, check=True, timeout=timeout)


project = work / "MenuUITests.xcodeproj"
project.mkdir()
source = root / ("Tests/TodayMenuJumpUITests.swift" if arguments.jump else "Tests/TodayMenuUITests.swift")
(project / "project.pbxproj").write_text('''// !$*UTF8*$!
{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {
A00000000000000000000001 = {isa = PBXProject; buildConfigurationList = A00000000000000000000002; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; mainGroup = A00000000000000000000003; productRefGroup = A00000000000000000000004; projectDirPath = ""; projectRoot = ""; targets = (A00000000000000000000005,); };
A00000000000000000000002 = {isa = XCConfigurationList; buildConfigurations = (A00000000000000000000006,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug; };
A00000000000000000000003 = {isa = PBXGroup; children = (A00000000000000000000007,A00000000000000000000004,); sourceTree = "<group>"; };
A00000000000000000000004 = {isa = PBXGroup; children = (A00000000000000000000008,); name = Products; sourceTree = "<group>"; };
A00000000000000000000005 = {isa = PBXNativeTarget; buildConfigurationList = A00000000000000000000009; buildPhases = (A00000000000000000000010,); buildRules = (); dependencies = (); name = MenuUITests; productName = MenuUITests; productReference = A00000000000000000000008; productType = "com.apple.product-type.bundle.ui-testing"; };
A00000000000000000000006 = {isa = XCBuildConfiguration; buildSettings = {SDKROOT = iphonesimulator; IPHONEOS_DEPLOYMENT_TARGET = 18.6; ALWAYS_SEARCH_USER_PATHS = NO; }; name = Debug; };
A00000000000000000000007 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "SOURCE_PATH"; sourceTree = "<absolute>"; };
A00000000000000000000008 = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = MenuUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
A00000000000000000000009 = {isa = XCConfigurationList; buildConfigurations = (A00000000000000000000011,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug; };
A00000000000000000000010 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (A00000000000000000000012,); runOnlyForDeploymentPostprocessing = 0; };
A00000000000000000000011 = {isa = XCBuildConfiguration; buildSettings = {GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = devplaceholder.CookJotMenuUITests; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = "1,2"; CODE_SIGNING_ALLOWED = NO; }; name = Debug; };
A00000000000000000000012 = {isa = PBXBuildFile; fileRef = A00000000000000000000007; };
}; rootObject = A00000000000000000000001; }
'''.replace("SOURCE_PATH", str(source)))
scheme_dir = project / "xcshareddata/xcschemes"
scheme_dir.mkdir(parents=True)
reference = '<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="A00000000000000000000005" BuildableName="MenuUITests.xctest" BlueprintName="MenuUITests" ReferencedContainer="container:MenuUITests.xcodeproj"/>'
(scheme_dir / "MenuUITests.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{reference}</TestableReference></Testables></TestAction>
</Scheme>''')

if arguments.build_only:
    run(["xcodebuild", "-project", str(project), "-scheme", "MenuUITests", "-configuration", "Debug",
         "-destination", "generic/platform=iOS Simulator", "-derivedDataPath", str(work / "TestBuild"),
         "build-for-testing"], "ui-tests-build.log")
    raise SystemExit(0)

device = arguments.device
inventory = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"], text=True))["devices"]
selected = next((item for devices in inventory.values() for item in devices if item["udid"] == device), None)
if selected is None or not selected.get("isAvailable"):
    raise SystemExit(f"Existing simulator is unavailable: {device}")
if selected["state"] != "Booted":
    run(["xcrun", "simctl", "boot", device], timeout=60)
run(["xcrun", "simctl", "bootstatus", device, "-b"], "boot.log", timeout=90)

app_project = root / "CookJot.xcodeproj"
if arguments.jump:
    # Compile production sources with a test-only App entry point. No launch hooks ship in CookJot.
    shutil.copytree(root / "CookJot", work / "CookJot")
    shutil.copy2(root / "Tests/TodayMenuJumpTestApp.swift", work / "CookJot/MyApp.swift")
    app_project = work / "CookJot.xcodeproj"
    shutil.copytree(root / "CookJot.xcodeproj", app_project)
run(["xcodebuild", "-project", str(app_project), "-scheme", "CookJot",
     "-configuration", "Debug", "-destination", f"id={device}",
     "-derivedDataPath", str(work / "AppBuild"), "CODE_SIGNING_ALLOWED=NO",
     "PRODUCT_BUNDLE_IDENTIFIER=devplaceholder.CookJotMenuUI", "build"], "app-build.log")
app_path = work / "AppBuild/Build/Products/Debug-iphonesimulator/CookJot.app"
# Reset only the dedicated test bundle's data; never erase the user's simulator or CookJot bundle.
subprocess.run(["xcrun", "simctl", "uninstall", device, "devplaceholder.CookJotMenuUI"], check=False, timeout=60)
run(["xcrun", "simctl", "install", device, str(app_path)])
run(["xcodebuild", "-project", str(project), "-scheme", "MenuUITests", "-configuration", "Debug",
     "-destination", f"id={device}", "-derivedDataPath", str(work / "TestBuild"),
     "build-for-testing"], "ui-tests-build.log")
print("UI test compilation succeeded", flush=True)
xctestrun = next((work / "TestBuild/Build/Products").glob("*.xctestrun"))
configuration = plistlib.loads(xctestrun.read_bytes())
if "TestConfigurations" in configuration:
    targets = [target for item in configuration["TestConfigurations"] for target in item["TestTargets"]]
else:
    targets = [value for key, value in configuration.items() if not key.startswith("__") and isinstance(value, dict)]
for target in targets:
    target["UITargetAppPath"] = str(app_path)
    target["UITargetAppBundleIdentifier"] = "devplaceholder.CookJotMenuUI"
xctestrun.write_bytes(plistlib.dumps(configuration))
command = ["xcodebuild", "test-without-building", "-xctestrun", str(xctestrun),
           "-destination", f"id={device}", "-resultBundlePath", str(work / "MenuUITests.xcresult"),
           "-parallel-testing-enabled", "NO", "-test-timeouts-enabled", "YES",
           "-default-test-execution-time-allowance", "120", "-maximum-test-execution-time-allowance", "180"]
for identifier in arguments.only_testing:
    command.append("-only-testing:" + identifier)
run(command, "ui-tests.log", timeout=900)
print("UI test execution succeeded", flush=True)
# Keep the user's existing simulator running; do not create, erase, or delete devices.
