#!/usr/bin/env python3
import os
import re
import sys
from pathlib import Path
import subprocess

def print_color(text, color):
    """Print colored text to the terminal"""
    colors = {
        'red': '\033[91m',
        'green': '\033[92m',
        'yellow': '\033[93m',
        'blue': '\033[94m',
        'purple': '\033[95m',
        'cyan': '\033[96m',
        'reset': '\033[0m'
    }
    print(f"{colors.get(color, '')}{text}{colors['reset']}")

def print_info(text):
    print_color(text, 'cyan')

def print_success(text):
    print_color(text, 'green')

def print_error(text):
    print_color(text, 'red')

def backup_file(file_path):
    """Create a backup of a file"""
    backup_path = f"{file_path}.backup"
    try:
        with open(file_path, 'r') as src:
            content = src.read()
        with open(backup_path, 'w') as dest:
            dest.write(content)
        print_info(f"Created backup: {backup_path}")
        return True
    except Exception as e:
        print_error(f"Failed to backup file: {str(e)}")
        return False

def find_project_file():
    """Find the Xcode project file in the current directory"""
    for item in Path('.').glob('*.xcodeproj'):
        if item.is_dir():
            project_file = item / 'project.pbxproj'
            if project_file.exists():
                return str(project_file)
    return None

def clean_derived_data():
    """Clean up the derived data for this project"""
    try:
        derived_data_path = os.path.expanduser("~/Library/Developer/Xcode/DerivedData")
        if not os.path.exists(derived_data_path):
            return

        print_info("Cleaning derived data...")
        for item in os.listdir(derived_data_path):
            if item.startswith("sign2text-app-"):
                item_path = os.path.join(derived_data_path, item)
                print_info(f"Removing {item_path}")
                subprocess.run(["rm", "-rf", item_path], check=False)
    except Exception as e:
        print_error(f"Error cleaning derived data: {str(e)}")

def fix_info_plist_issue():
    """Fix the Info.plist conflict issue"""
    project_file = find_project_file()
    if not project_file:
        print_error("Could not find Xcode project file")
        return False

    print_info(f"Found project file: {project_file}")

    # Backup the project file before making changes
    if not backup_file(project_file):
        return False

    try:
        # Delete any existing Info.plist file in the project directory
        info_plist_path = Path("sign2text-app/Info.plist")
        if info_plist_path.exists():
            print_info("Removing existing Info.plist file")
            os.remove(info_plist_path)

        # Read the project file
        with open(project_file, 'r') as f:
            content = f.read()

        # Remove INFOPLIST_FILE references
        content = content.replace('INFOPLIST_FILE = "sign2text-app/Info.plist";', '')

        # Add GENERATE_INFOPLIST_FILE settings
        content = content.replace('DEVELOPMENT_ASSET_PATHS = "sign2text-app/Preview Content";',
                              'DEVELOPMENT_ASSET_PATHS = "sign2text-app/Preview Content";\n\t\t\t\tGENERATE_INFOPLIST_FILE = YES;\n\t\t\t\tINFOPLIST_KEY_NSCameraUsageDescription = "Camera access is required to translate sign language into text";')

        # Write the modified content back to the project file
        with open(project_file, 'w') as f:
            f.write(content)

        print_success("Project file updated to use generated Info.plist")

        # Clean the derived data to ensure a fresh build
        clean_derived_data()

        return True
    except Exception as e:
        print_error(f"Error updating project file: {str(e)}")
        return False

def main():
    print_info("Starting Info.plist conflict resolution script...")

    if fix_info_plist_issue():
        print_success("\nInfo.plist conflict resolution completed successfully!")
        print_info("\nPlease follow these steps to complete the process:")
        print_info("1. Close Xcode if it's open")
        print_info("2. Open the project again")
        print_info("3. Clean the build folder (Product > Clean Build Folder)")
        print_info("4. Build and run the app")
        return 0
    else:
        print_error("\nFailed to resolve Info.plist conflict")
        return 1

if __name__ == "__main__":
    sys.exit(main())
