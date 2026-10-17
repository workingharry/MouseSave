#!/bin/bash
set -e

# ==============================================================================
# MouseSave macOS DMG Build Script
# Builds MouseSave.app in Release mode and packages it into a compressed DMG
# ==============================================================================

VERSION="1.2.0"
APP_NAME="MouseSave"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
DIST_DIR="${PROJECT_DIR}/dist"
DMG_TEMP="${PROJECT_DIR}/build/dmg_temp"
DMG_NAME="${APP_NAME}-v${VERSION}-macOS.dmg"

CLEAN_BUILD=false
AUTO_PUBLISH=true

for arg in "$@"; do
    case "$arg" in
        --clean) CLEAN_BUILD=true ;;
        --no-publish) AUTO_PUBLISH=false ;;
    esac
done

echo "==> Building ${APP_NAME} v${VERSION} for macOS..."
cd "${PROJECT_DIR}"

# 1. Clean build artifacts if requested, or ensure directories exist
if [ "$CLEAN_BUILD" = true ]; then
    echo "==> [Clean Build] Removing previous build directory..."
    rm -rf "${BUILD_DIR}"
fi
mkdir -p "${BUILD_DIR}"
mkdir -p "${DIST_DIR}"

# 2. Build Release using xcodebuild (Ad-Hoc signing for open-source distribution)
echo "==> Running xcodebuild..."
xcodebuild -project "${APP_NAME}.xcodeproj" \
           -scheme "${APP_NAME}" \
           -configuration Release \
           -derivedDataPath "${BUILD_DIR}/DerivedData" \
           CODE_SIGN_IDENTITY="-" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=YES \
           build

# 3. Locate compiled .app
APP_PATH="${BUILD_DIR}/DerivedData/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "${APP_PATH}" ]; then
    echo "Error: ${APP_PATH} not found!"
    exit 1
fi

# 4. Re-sign Ad-Hoc
echo "==> Applying Ad-Hoc code signature..."
codesign --force --deep --sign - "${APP_PATH}"

# 5. Prepare DMG staging directory
echo "==> Preparing DMG folder structure..."
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"
cp -R "${APP_PATH}" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

# 6. Create compressed DMG using hdiutil
echo "==> Creating compressed DMG: ${DIST_DIR}/${DMG_NAME}..."
rm -f "${DIST_DIR}/${DMG_NAME}"
hdiutil create -volname "${APP_NAME}" \
               -srcfolder "${DMG_TEMP}" \
               -ov \
               -format UDZO \
               "${DIST_DIR}/${DMG_NAME}"

# Clean staging directory
rm -rf "${DMG_TEMP}"

echo "================================================================="
echo "  SUCCESS: macOS DMG created at:"
echo "  ${DIST_DIR}/${DMG_NAME}"
echo "================================================================="

# --- Antigravity 集中交付管線整合 ---
if [ "$AUTO_PUBLISH" = true ]; then
    if command -v ag-publish >/dev/null 2>&1; then
        echo ""
        echo "==> 自動觸發 Antigravity 交付管線 (ag-publish)..."
        ag-publish "${DIST_DIR}/${DMG_NAME}" "${APP_NAME}" "${VERSION}"
        
        # 交付至集中目錄後，自動清除專案內的本地重複副本以杜絕硬碟肥大
        rm -f "${DIST_DIR}/${DMG_NAME}"
        echo "==> [防累贅] 已自動清除專案內部的重複 DMG 副本"
    else
        echo "提示: 未檢測到 ag-publish 工具，DMG 保留在 ${DIST_DIR}/${DMG_NAME}"
    fi
fi
