#!/bin/bash
set -e

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Paths
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_IPA="$PROJECT_DIR/assets/theta.ipa"
DEFAULT_OUTPUT="$PROJECT_DIR/output/theta_cracked.ipa"
DYLIB_NAME="ThetaCrack.dylib"
PLIST_NAME="com.jailbreakland.thetacrack.plist"

print_usage() {
    cat << EOF
Usage: $(basename "$0") [options]

Builds the ThetaCrack tweak and injects it into an IPA.

Options:
  -i, --ipa <path>       Path to the input IPA (default: assets/theta.ipa)
  -o, --output <path>    Path for the cracked IPA (default: output/theta_cracked.ipa)
  -h, --help             Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") -i ~/Downloads/theta.ipa
  $(basename "$0") -i ~/Downloads/theta.ipa -o ~/Desktop/cracked.ipa
EOF
}

# Parse arguments
IPA="$DEFAULT_IPA"
OUTPUT_IPA="$DEFAULT_OUTPUT"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--ipa)
            IPA="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_IPA="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            print_usage
            exit 1
            ;;
    esac
done

# Resolve absolute paths
mkdir -p "$(dirname "$OUTPUT_IPA")"
IPA="$(cd "$(dirname "$IPA")" && pwd)/$(basename "$IPA")"
OUTPUT_IPA="$(cd "$(dirname "$OUTPUT_IPA")" && pwd)/$(basename "$OUTPUT_IPA")"

# Validate IPA
if [[ ! -f "$IPA" ]]; then
    echo -e "${RED}Error: IPA not found: $IPA${NC}" >&2
    exit 1
fi

WORK_DIR="$PROJECT_DIR/_build_tmp"

echo -e "${BOLD}ThetaCrack Builder${NC}"
echo "  Input IPA:  $IPA"
echo "  Output:     $OUTPUT_IPA"
echo ""

# Step 1: Build tweak
echo -e "${BLUE}[1/6]${NC} Building tweak..."
cd "$PROJECT_DIR"
make clean >/dev/null
make >/dev/null

# Step 2: Extract IPA
echo -e "${BLUE}[2/6]${NC} Extracting IPA..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
unzip -o "$IPA" -d "$WORK_DIR" >/dev/null

APP_DIR=$(find "$WORK_DIR/Payload" -name "*.app" -type d | head -1)
TARGET_BINARY="$APP_DIR/Frameworks/Theta.dylib"

# Step 3: Inject tweak
echo -e "${BLUE}[3/6]${NC} Injecting tweak..."
cp "$PROJECT_DIR/.theos/obj/debug/$DYLIB_NAME" "$APP_DIR/$DYLIB_NAME"
cp "$PROJECT_DIR/layout/Library/MobileSubstrate/DynamicLibraries/$PLIST_NAME" "$APP_DIR/$PLIST_NAME"

# Step 4: Patch target dylib
echo -e "${BLUE}[4/6]${NC} Patching target dylib..."
ldid -R "$TARGET_BINARY" 2>/dev/null || true
insert_dylib --strip-codesig --all-yes "@executable_path/$DYLIB_NAME" "$TARGET_BINARY" "$TARGET_BINARY" 2>/dev/null || {
    echo -e "${YELLOW}    insert_dylib failed, trying --inplace...${NC}"
    insert_dylib --inplace --strip-codesig --all-yes "@executable_path/$DYLIB_NAME" "$TARGET_BINARY"
}

# Step 5: Sign binaries
echo -e "${BLUE}[5/6]${NC} Signing binaries..."
ldid -S "$APP_DIR/$DYLIB_NAME"
ldid -S "$TARGET_BINARY"

# Step 6: Repack
echo -e "${BLUE}[6/6]${NC} Repacking IPA..."
rm -f "$OUTPUT_IPA"
cd "$WORK_DIR" && zip -qr "$OUTPUT_IPA" Payload/
rm -rf "$WORK_DIR"

OUTPUT_SIZE=$(du -h "$OUTPUT_IPA" | cut -f1)
echo ""
echo -e "${GREEN}Done!${NC} Output: $OUTPUT_IPA ($OUTPUT_SIZE)"
