#!/usr/bin/env python3
"""Add staging/production iOS build configurations and Firebase copy script."""

from pathlib import Path

PBX = Path(__file__).resolve().parents[1] / "ios" / "Runner.xcodeproj" / "project.pbxproj"

# File references for flavor xcconfigs
XCCONFIG_REFS = """
		A1000001E8E89220040F4C1 /* Debug-production.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = "Debug-production.xcconfig"; path = "Flutter/Debug-production.xcconfig"; sourceTree = "<group>"; };
		A1000002E8E89220040F4C1 /* Release-production.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = "Release-production.xcconfig"; path = "Flutter/Release-production.xcconfig"; sourceTree = "<group>"; };
		A1000003E8E89220040F4C1 /* Profile-production.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = "Profile-production.xcconfig"; path = "Flutter/Profile-production.xcconfig"; sourceTree = "<group>"; };
		A1000004E8E89220040F4C1 /* Debug-staging.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = "Debug-staging.xcconfig"; path = "Flutter/Debug-staging.xcconfig"; sourceTree = "<group>"; };
		A1000005E8E89220040F4C1 /* Release-staging.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = "Release-staging.xcconfig"; path = "Flutter/Release-staging.xcconfig"; sourceTree = "<group>"; };
		A1000006E8E89220040F4C1 /* Profile-staging.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = "Profile-staging.xcconfig"; path = "Flutter/Profile-staging.xcconfig"; sourceTree = "<group>"; };
		A1000007E8E89220040F4C1 /* GoogleService-Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "GoogleService-Info.plist"; sourceTree = "<group>"; };
"""

XCCONFIG_GROUP_CHILDREN = """
				A1000001E8E89220040F4C1 /* Debug-production.xcconfig */,
				A1000002E8E89220040F4C1 /* Release-production.xcconfig */,
				A1000003E8E89220040F4C1 /* Profile-production.xcconfig */,
				A1000004E8E89220040F4C1 /* Debug-staging.xcconfig */,
				A1000005E8E89220040F4C1 /* Release-staging.xcconfig */,
				A1000006E8E89220040F4C1 /* Profile-staging.xcconfig */,
"""

RUNNER_GROUP_CHILDREN = """
				A1000007E8E89220040F4C1 /* GoogleService-Info.plist */,
"""

BUILD_FILE = """
		A1000008E8E89220040F4C1 /* GoogleService-Info.plist in Resources */ = {isa = PBXBuildFile; fileRef = A1000007E8E89220040F4C1 /* GoogleService-Info.plist */; };
"""

FIREBASE_SCRIPT = """
		A1000009E8E89220040F4C1 /* Copy Firebase Plist */ = {
			isa = PBXShellScriptBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			inputPaths = (
			);
			name = "Copy Firebase Plist";
			outputPaths = (
				"$(PROJECT_DIR)/Runner/GoogleService-Info.plist",
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "/bin/sh \\"${PROJECT_DIR}/Runner/copy_firebase_plist.sh\\"\\n";
		};
"""

RUNNER_TARGET_SETTINGS = """\
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CLANG_ENABLE_MODULES = YES;
				CURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";
				ENABLE_BITCODE = NO;
				INFOPLIST_FILE = Runner/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_OBJC_BRIDGING_HEADER = "Runner/Runner-Bridging-Header.h";
				SWIFT_VERSION = 5.0;
				VERSIONING_SYSTEM = "apple-generic";
"""

PROJECT_DEBUG_SETTINGS = """\
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++0x";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer";
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = NO;
				GCC_C_LANGUAGE_STANDARD = gnu99;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 13.0;
				MTL_ENABLE_DEBUG_INFO = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				TARGETED_DEVICE_FAMILY = "1,2";
"""

NEW_BUILD_CONFIGS = f"""
		A1000021E8E89220040F4C1 /* Debug-production */ = {{
			isa = XCBuildConfiguration;
			baseConfigurationReference = A1000001E8E89220040F4C1 /* Debug-production.xcconfig */;
			buildSettings = {{
{RUNNER_TARGET_SETTINGS}
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			}};
			name = "Debug-production";
		}};
		A1000022E8E89220040F4C1 /* Release-production */ = {{
			isa = XCBuildConfiguration;
			baseConfigurationReference = A1000002E8E89220040F4C1 /* Release-production.xcconfig */;
			buildSettings = {{
{RUNNER_TARGET_SETTINGS}
			}};
			name = "Release-production";
		}};
		A1000023E8E89220040F4C1 /* Profile-production */ = {{
			isa = XCBuildConfiguration;
			baseConfigurationReference = A1000003E8E89220040F4C1 /* Profile-production.xcconfig */;
			buildSettings = {{
{RUNNER_TARGET_SETTINGS}
			}};
			name = "Profile-production";
		}};
		A1000024E8E89220040F4C1 /* Debug-staging */ = {{
			isa = XCBuildConfiguration;
			baseConfigurationReference = A1000004E8E89220040F4C1 /* Debug-staging.xcconfig */;
			buildSettings = {{
{RUNNER_TARGET_SETTINGS}
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			}};
			name = "Debug-staging";
		}};
		A1000025E8E89220040F4C1 /* Release-staging */ = {{
			isa = XCBuildConfiguration;
			baseConfigurationReference = A1000005E8E89220040F4C1 /* Release-staging.xcconfig */;
			buildSettings = {{
{RUNNER_TARGET_SETTINGS}
			}};
			name = "Release-staging";
		}};
		A1000026E8E89220040F4C1 /* Profile-staging */ = {{
			isa = XCBuildConfiguration;
			baseConfigurationReference = A1000006E8E89220040F4C1 /* Profile-staging.xcconfig */;
			buildSettings = {{
{RUNNER_TARGET_SETTINGS}
			}};
			name = "Profile-staging";
		}};
		A1000031E8E89220040F4C1 /* Debug-staging */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{PROJECT_DEBUG_SETTINGS}
			}};
			name = "Debug-staging";
		}};
		A1000032E8E89220040F4C1 /* Release-staging */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++0x";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer";
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = NO;
				GCC_C_LANGUAGE_STANDARD = gnu99;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 13.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				TARGETED_DEVICE_FAMILY = "1,2";
				VALIDATE_PRODUCT = YES;
			}};
			name = "Release-staging";
		}};
		A1000033E8E89220040F4C1 /* Profile-staging */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++0x";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer";
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = NO;
				GCC_C_LANGUAGE_STANDARD = gnu99;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 13.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = iphoneos;
				TARGETED_DEVICE_FAMILY = "1,2";
				VALIDATE_PRODUCT = YES;
			}};
			name = "Profile-staging";
		}};
"""


def patch(text: str) -> str:
    if "Debug-production" in text:
        print("Already patched — skipping.")
        return text

    text = text.replace(
        "/* End PBXBuildFile section */",
        BUILD_FILE + "/* End PBXBuildFile section */",
    )
    text = text.replace(
        "/* End PBXFileReference section */",
        XCCONFIG_REFS + "/* End PBXFileReference section */",
    )
    text = text.replace(
        "9740EEB31CF90195004384FC /* Generated.xcconfig */,\n",
        "9740EEB31CF90195004384FC /* Generated.xcconfig */,\n" + XCCONFIG_GROUP_CHILDREN,
    )
    text = text.replace(
        "97C147021CF9000F007C117D /* Info.plist */,\n",
        "97C147021CF9000F007C117D /* Info.plist */,\n" + RUNNER_GROUP_CHILDREN,
    )
    text = text.replace(
        "buildPhases = (\n\t\t\t\t9740EEB61CF901F6004384FC /* Run Script */,",
        "buildPhases = (\n\t\t\t\tA1000009E8E89220040F4C1 /* Copy Firebase Plist */,\n\t\t\t\t9740EEB61CF901F6004384FC /* Run Script */,",
    )
    text = text.replace(
        "/* End PBXShellScriptBuildPhase section */",
        FIREBASE_SCRIPT + "/* End PBXShellScriptBuildPhase section */",
    )
    text = text.replace(
        "97C146FC1CF9000F007C117D /* Main.storyboard in Resources */,\n",
        "A1000008E8E89220040F4C1 /* GoogleService-Info.plist in Resources */,\n\t\t\t\t97C146FC1CF9000F007C117D /* Main.storyboard in Resources */,\n",
    )

    # Point legacy Runner configs at production xcconfigs; bundle id comes from xcconfig.
    text = text.replace(
        "97C147061CF9000F007C117D /* Debug */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbaseConfigurationReference = 9740EEB21CF90195004384FC /* Debug.xcconfig */;",
        "97C147061CF9000F007C117D /* Debug */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbaseConfigurationReference = A1000001E8E89220040F4C1 /* Debug-production.xcconfig */;",
    )
    text = text.replace(
        "97C147071CF9000F007C117D /* Release */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbaseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;",
        "97C147071CF9000F007C117D /* Release */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbaseConfigurationReference = A1000002E8E89220040F4C1 /* Release-production.xcconfig */;",
    )
    text = text.replace(
        "249021D4217E4FDB00AE95B9 /* Profile */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbaseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;",
        "249021D4217E4FDB00AE95B9 /* Profile */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbaseConfigurationReference = A1000003E8E89220040F4C1 /* Profile-production.xcconfig */;",
    )

    for old in (
        "PRODUCT_BUNDLE_IDENTIFIER = com.example.mprsAndroid;",
        "PRODUCT_BUNDLE_IDENTIFIER = com.example.mprsAndroid.RunnerTests;",
    ):
        text = text.replace(old, "")

    text = text.replace(
        "/* End XCBuildConfiguration section */",
        NEW_BUILD_CONFIGS + "\t\t/* End XCBuildConfiguration section */",
    )

    text = text.replace(
        "97C146E91CF9000F007C117D /* Build configuration list for PBXProject \"Runner\" */ = {\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t97C147031CF9000F007C117D /* Debug */,\n\t\t\t\t97C147041CF9000F007C117D /* Release */,\n\t\t\t\t249021D3217E4FDB00AE95B9 /* Profile */,\n\t\t\t);",
        "97C146E91CF9000F007C117D /* Build configuration list for PBXProject \"Runner\" */ = {\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t97C147031CF9000F007C117D /* Debug */,\n\t\t\t\t97C147041CF9000F007C117D /* Release */,\n\t\t\t\t249021D3217E4FDB00AE95B9 /* Profile */,\n\t\t\t\tA1000031E8E89220040F4C1 /* Debug-staging */,\n\t\t\t\tA1000032E8E89220040F4C1 /* Release-staging */,\n\t\t\t\tA1000033E8E89220040F4C1 /* Profile-staging */,\n\t\t\t);",
    )

    text = text.replace(
        "97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget \"Runner\" */ = {\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t97C147061CF9000F007C117D /* Debug */,\n\t\t\t\t97C147071CF9000F007C117D /* Release */,\n\t\t\t\t249021D4217E4FDB00AE95B9 /* Profile */,\n\t\t\t);",
        "97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget \"Runner\" */ = {\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t97C147061CF9000F007C117D /* Debug */,\n\t\t\t\t97C147071CF9000F007C117D /* Release */,\n\t\t\t\t249021D4217E4FDB00AE95B9 /* Profile */,\n\t\t\t\tA1000021E8E89220040F4C1 /* Debug-production */,\n\t\t\t\tA1000022E8E89220040F4C1 /* Release-production */,\n\t\t\t\tA1000023E8E89220040F4C1 /* Profile-production */,\n\t\t\t\tA1000024E8E89220040F4C1 /* Debug-staging */,\n\t\t\t\tA1000025E8E89220040F4C1 /* Release-staging */,\n\t\t\t\tA1000026E8E89220040F4C1 /* Profile-staging */,\n\t\t\t);",
    )

    return text


def main() -> None:
    original = PBX.read_text(encoding="utf-8")
    updated = patch(original)
    PBX.write_text(updated, encoding="utf-8")
    print(f"Patched {PBX}")


if __name__ == "__main__":
    main()
