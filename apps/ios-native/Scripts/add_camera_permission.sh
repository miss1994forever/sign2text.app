#!/bin/bash

# Script to add camera permission to the Xcode project
# This script is designed to be run manually once to configure the project

# Check if we're in the right directory
if [[ ! -d "sign2text-app.xcodeproj" ]]; then
    echo "Error: Must run from the project root directory (containing sign2text-app.xcodeproj)"
    exit 1
fi

# Path to the project.pbxproj file
PROJ_FILE="sign2text-app.xcodeproj/project.pbxproj"

# Ensure the project file exists
if [[ ! -f "$PROJ_FILE" ]]; then
    echo "Error: Project file not found at $PROJ_FILE"
    exit 1
fi

# Backup the project file
cp "$PROJ_FILE" "${PROJ_FILE}.bak"
echo "Created backup at ${PROJ_FILE}.bak"

# Find the target build settings for the main app
TARGET_SECTION=$(grep -n "buildSettings = {" "$PROJ_FILE" | head -1 | cut -d':' -f1)
if [[ -z "$TARGET_SECTION" ]]; then
    echo "Error: Could not find build settings section"
    exit 1
fi

# Check if camera permission is already added
if grep -q "NSCameraUsageDescription" "$PROJ_FILE"; then
    echo "Camera permission already exists in the project file"
else
    # Add camera permission to the build settings
    # We'll insert it after the GENERATE_INFOPLIST_FILE line if present
    if grep -q "GENERATE_INFOPLIST_FILE = YES" "$PROJ_FILE"; then
        # Using awk to insert after the GENERATE_INFOPLIST_FILE line
        awk '/GENERATE_INFOPLIST_FILE = YES;/{print; print "\t\t\t\tINFOPLIST_KEY_NSCameraUsageDescription = \"Camera access is required to translate sign language into text.\";"; next}1' "$PROJ_FILE" > "$PROJ_FILE.tmp"
        mv "$PROJ_FILE.tmp" "$PROJ_FILE"
        echo "Added camera permission to the project settings"
    else
        # If GENERATE_INFOPLIST_FILE isn't found, add our keys in a reasonable location
        # This is more complex, we'll add near another INFOPLIST entry
        awk '/INFOPLIST_KEY_UI/{if (!found) {print; print "\t\t\t\tINFOPLIST_KEY_NSCameraUsageDescription = \"Camera access is required to translate sign language into text.\";"; found=1} else {print}; next}1' "$PROJ_FILE" > "$PROJ_FILE.tmp"
        mv "$PROJ_FILE.tmp" "$PROJ_FILE"
        echo "Added camera permission to the project settings (alternative location)"
    fi
fi

# Remove extended attributes that Xcode might have added
xattr -c "$PROJ_FILE" 2>/dev/null || true

echo "Script completed successfully"
echo "Please clean the build folder (Product > Clean Build Folder) and rebuild your project"
