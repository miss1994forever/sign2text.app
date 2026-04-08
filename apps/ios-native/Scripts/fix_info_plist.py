#!/usr/bin/env python3
import sys
import os
import re
import subprocess
from pathlib import Path

def print_color(text, color_code):
    """Print colored text to the terminal"""
    print(f"\033[{color_code}m{text}\033[0m")

def print_info(text):
    print_color(text, 36)  # Cyan

def print_success(text):
    print_color(text, 32)  # Green

def print_error(text):
    print_color(text, 31)  # Red

def print_warning(text):
    print_color(text, 33)  # Yellow

def find_project_file(path="."):
    """Find the Xcode project file in the given path"""
    for item in Path(path).glob("*.xcodeproj"):
        if item.is_dir():
            pbxproj = item / "project.pbxproj"
            if pbxproj.exists():
                return str(pbxproj)
    return None

def backup_file(file_path):
    """Create a backup of the file"""
    backup_path = f"{file_path}.bak"
    try:
        with open(file_path, 'r') as src:
            with open(backup_path, 'w') as dst:
                dst.write(src.read())
        print_info(f"Backup created at {backup_path}")
        return True
    except Exception as e:
        print_error(f"Failed to create backup: {e}")
        return False

def fix_info_plist_issue(project_file):
    """Fix the Info.plist conflict in the project file"""
    if not os.path.exists(project_file):
        print_error(f"Project file not found: {project_file}")
        return False

    # Create a backup before modifying
    if not backup_file(project_file):
        return False

    try:
        # Read the project file
        with open(project_file, 'r') as f:
            content = f.read()

        # Check if GENERATE_INFOPLIST_FILE is already set
        if 'GENERATE_INFOPLIST_FILE = YES' in content:
            print_info("Project is already using generated Info.plist")

            # Make sure there's no explicit Info.plist file reference
            # Look for patterns that might indicate an explicit Info.plist file
            infoplist_file_pattern = r'INFOPLIST_FILE\s*=\s*"[^"]*";'
            match = re.search(infoplist_file_pattern, content)

            if match:
                # Remove the INFOPLIST_FILE entry
                print_warning("Found explicit Info.plist reference, removing it")
                content = re.sub(infoplist_file_pattern, '', content)

                # Write the updated content
                with open(project_file, 'w') as f:
                    f.write(content)
                print_success("Removed explicit Info.plist reference")
            else:
                # If no explicit reference found, add the camera usage description
                if 'NSCameraUsageDescription' not in content:
                    # Add the camera usage description to project settings
                    # Find a reasonable place to insert it - after GENERATE_INFOPLIST_FILE
                    pattern = r'(GENERATE_INFOPLIST_FILE = YES;)'
                    replacement = r'\1\n\t\t\t\tINFOPLIST_KEY_NSCameraUsageDescription = "Camera access is required to translate sign language into text.";'
                    content = re.sub(pattern, replacement, content, count=1)

                    # Write the updated content
                    with open(project_file, 'w') as f:
                        f.write(content)
                    print_success("Added NSCameraUsageDescription to generated Info.plist")
                else:
                    print_info("Camera usage description already exists")
        else:
            print_warning("Project is not configured to generate Info.plist automatically")
            print_info("Switching to generated Info.plist mode...")

            # Find the build settings section(s)
            build_settings_pattern = r'buildSettings = \{([^}]*)\};'
            matches = re.finditer(build_settings_pattern, content)

            # Replace in the first match (main target)
            count = 0
            new_content = content
            for match in matches:
                build_settings = match.group(1)
                if 'PRODUCT_BUNDLE_IDENTIFIER' in build_settings and 'UITests' not in build_settings:
                    # This is likely the main target
                    updated_settings = build_settings + '\n\t\t\t\tGENERATE_INFOPLIST_FILE = YES;'
                    updated_settings += '\n\t\t\t\tINFOPLIST_KEY_NSCameraUsageDescription = "Camera access is required to translate sign language into text.";'

                    # Replace the build settings
                    start, end = match.span(1)
                    new_content = new_content[:start] + updated_settings + new_content[end:]
                    count += 1
                    if count == 1:  # Only update the main target
                        break

            # Write the updated content
            if count > 0:
                with open(project_file, 'w') as f:
                    f.write(new_content)
                print_success("Updated project to use generated Info.plist with camera permission")
            else:
                print_error("Could not find main target build settings")
                return False

        # Clean build folder to ensure changes take effect
        print_info("Cleaning derived data to ensure changes take effect...")
        try:
            home = os.path.expanduser("~")
            derived_data = os.path.join(home, "Library/Developer/Xcode/DerivedData")
            if os.path.exists(derived_data):
                for item in os.listdir(derived_data):
                    if item.startswith("sign2text-app-"):
                        path = os.path.join(derived_data, item)
                        subprocess.run(["rm", "-rf", path])
                print_success("Cleaned derived data")
        except Exception as e:
            print_warning(f"Failed to clean derived data: {e}")

        return True
    except Exception as e:
        print_error(f"Error fixing Info.plist issue: {e}")
        return False

def main():
    """Main function"""
    print_info("Starting Info.plist conflict resolution script...")

    # Find the project file
    project_file = find_project_file()
    if not project_file:
        print_error("Could not find Xcode project file")
        return 1

    print_info(f"Found project file: {project_file}")

    # Fix the Info.plist issue
    if fix_info_plist_issue(project_file):
        print_success("\nInfo.plist conflict resolution completed successfully!")
        print_info("\nPlease follow these steps to complete the process:")
        print_info("1. Close Xcode if it's open")
        print_info("2. Open the project again")
        print_info("3. Clean the build folder (Product > Clean Build Folder)")
        print_info("4. Build and run the app")
        return 0
    else:
        print_error("\nFailed to resolve Info.plist conflict")
        print_warning("\nManual solution:")
        print_info("1. Open the project in Xcode")
        print_info("2. Select the project in the navigator")
        print_info("3. Select the target in the editor")
        print_info("4. Go to the Build Settings tab")
        print_info("5. Search for 'info.plist'")
        print_info("6. Make sure 'Generate Info.plist File' is set to Yes")
        print_info("7. Remove any explicit 'Info.plist File' entry")
        print_info("8. Add 'NSCameraUsageDescription' in the Info tab")
        return 1

if __name__ == "__main__":
    sys.exit(main())
