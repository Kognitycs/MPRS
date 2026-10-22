#!/usr/bin/env python3
"""Wire Runner.entitlements into all Runner target build configurations."""

from pathlib import Path

PBX = Path(__file__).resolve().parents[1] / "ios" / "Runner.xcodeproj" / "project.pbxproj"

ENTITLEMENTS_REF = """
		A1000011E8E89220040F4C1 /* Runner.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Runner.entitlements; sourceTree = "<group>"; };
"""

ENTITLEMENTS_GROUP = """
				A1000011E8E89220040F4C1 /* Runner.entitlements */,
"""

ENTITLEMENTS_SETTING = "\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n"


def patch(text: str) -> str:
    if "Runner.entitlements" in text:
        print("Entitlements already wired — skipping.")
        return text

    text = text.replace(
        "/* End PBXFileReference section */",
        ENTITLEMENTS_REF + "/* End PBXFileReference section */",
    )
    text = text.replace(
        "97C147021CF9000F007C117D /* Info.plist */,\n",
        "97C147021CF9000F007C117D /* Info.plist */,\n" + ENTITLEMENTS_GROUP,
    )

    # Runner app target configs only (have INFOPLIST_FILE = Runner/Info.plist).
    marker = "INFOPLIST_FILE = Runner/Info.plist;\n"
    text = text.replace(marker, marker + ENTITLEMENTS_SETTING)

    return text


def main() -> None:
    original = PBX.read_text(encoding="utf-8")
    updated = patch(original)
    PBX.write_text(updated, encoding="utf-8")
    print(f"Patched {PBX}")


if __name__ == "__main__":
    main()
