#!/usr/bin/env python3

import os
import re
import sys
import subprocess
from pathlib import Path

# Color formatting for terminal output
def print_color(text, color_code):
    """Print text in color to the terminal"""
    print(f"\033[{color_code}m{text}\033[0m")

def print_info(text):
    print_color(text, 36)  # Cyan

def print_success(text):
    print_color(text, 32)  # Green

def print_error(text):
    print_color(text, 31)  # Red

def print_warning(text):
    print_color(text, 33)  # Yellow

def find_xcode_project(path="."):
    """Find the Xcode project directory"""
    for item in Path(path).glob("*.xcodeproj"):
        if item.is_dir():
            return str(item)
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

def find_pbxproj_file(xcode_project_path):
    """Find the project.pbxproj file in the Xcode project"""
    pbxproj_path = os.path.join(xcode_project_path, "project.pbxproj")
    if os.path.exists(pbxproj_path):
        return pbxproj_path
    return None

def ensure_info_plist_in_project(xcode_project_path, app_name="sign2text-app"):
    """Ensure that Info.plist is properly included in the project"""
    pbxproj_path = find_pbxproj_file(xcode_project_path)
    if not pbxproj_path:
        print_error(f"Could not find project.pbxproj in {xcode_project_path}")
        return False

    # Create a backup before modifying
    if not backup_file(pbxproj_path):
        return False

    # Extract the app directory name from the project path
    app_dir = os.path.basename(os.path.dirname(xcode_project_path))

    # Read the project file
    try:
        with open(pbxproj_path, 'r') as f:
            content = f.read()

        # Check if Info.plist is already referenced as a file
        if re.search(r'Info\.plist in "?FileRef"?', content):
            print_info("Info.plist is already referenced in the project file")

            # Update INFOPLIST_FILE paths to use the correct format
            if 'INFOPLIST_FILE = sign2text-app/Info.plist;' in content:
                content = content.replace(
                    'INFOPLIST_FILE = sign2text-app/Info.plist;',
                    f'INFOPLIST_FILE = "{app_name}/Info.plist";'
                )
                print_info("Updated INFOPLIST_FILE paths to use quotes")

                # Write the updated content
                with open(pbxproj_path, 'w') as f:
                    f.write(content)

            return True

        # Info.plist is not referenced, so we need to add it

        # 1. Find a PBXFileReference section
        file_ref_section_match = re.search(r'\/\* Begin PBXFileReference section \*\/\n(.+?)\/\* End PBXFileReference section \*\/',
                                           content, re.DOTALL)

        if not file_ref_section_match:
            print_error("Could not find PBXFileReference section in project file")
            return False

        file_ref_section = file_ref_section_match.group(1)
        file_ref_section_start = file_ref_section_match.start(1)

        # 2. Generate a new file reference UUID
        # Extract existing UUIDs and create a new one
        uuid_pattern = r'([0-9A-F]{24})'
        uuids = re.findall(uuid_pattern, content)

        import uuid
        new_uuid = uuid.uuid4().hex.upper()[0:24]
        while new_uuid in uuids:
            new_uuid = uuid.uuid4().hex.upper()[0:24]

        # 3. Create the Info.plist file reference entry
        info_plist_ref = f'''{new_uuid} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "Info.plist"; sourceTree = "<group>"; }};
'''

        # 4. Insert the new file reference into the PBXFileReference section
        updated_content = content[:file_ref_section_start] + info_plist_ref + content[file_ref_section_start:]

        # 5. Find the main group (usually the app group)
        app_group_pattern = fr'([0-9A-F]{{24}}) /\* {app_name} \*/ = {{isa = PBXGroup; children = \('
        app_group_match = re.search(app_group_pattern, updated_content)

        if not app_group_match:
            print_error(f"Could not find the main app group in project file")
            return False

        # 6. Add the Info.plist to the app's file group
        group_start = app_group_match.start()
        children_start = app_group_match.end()

        # Find the closing parenthesis for the children list
        children_end = updated_content.find(')', children_start)
        if children_end == -1:
            print_error("Could not find the end of the children list")
            return False

        # Add our new file reference to the children list
        children_list = updated_content[children_start:children_end]
        if "/* Info.plist */" not in children_list:
            if children_list.strip():
                # If there are already items, add a comma
                children_list += f",\n\t\t\t\t{new_uuid} /* Info.plist */"
            else:
                # If this is the first item, no comma needed
                children_list = f"\n\t\t\t\t{new_uuid} /* Info.plist */"

            updated_content = (
                updated_content[:children_start] +
                children_list +
                updated_content[children_end:]
            )

        # 7. Update INFOPLIST_FILE build settings for each target
        build_settings_pattern = r'buildSettings = \{(.*?)\};'

        def replace_build_settings(match):
            build_settings = match.group(1)
            if 'GENERATE_INFOPLIST_FILE = YES;' in build_settings:
                # Replace GENERATE_INFOPLIST_FILE with INFOPLIST_FILE
                build_settings = build_settings.replace(
                    'GENERATE_INFOPLIST_FILE = YES;',
                    f'INFOPLIST_FILE = "{app_name}/Info.plist";'
                )
            elif 'INFOPLIST_FILE' not in build_settings:
                # Add INFOPLIST_FILE if it doesn't exist
                build_settings += f'\n\t\t\t\tINFOPLIST_FILE = "{app_name}/Info.plist";'

            return f'buildSettings = {{{build_settings}}};'

        updated_content = re.sub(build_settings_pattern, replace_build_settings, updated_content, flags=re.DOTALL)

        # 8. Write the updated content back to the project file
        with open(pbxproj_path, 'w') as f:
            f.write(updated_content)

        print_success("Added Info.plist to the project file")
        return True

    except Exception as e:
        print_error(f"Error updating project file: {e}")
        return False

def clean_derived_data():
    """Clean Xcode derived data for the app"""
    try:
        home = os.path.expanduser("~")
        derived_data = os.path.join(home, "Library/Developer/Xcode/DerivedData")

        if not os.path.exists(derived_data):
            print_info("Derived data directory not found")
            return

        count = 0
        for item in os.listdir(derived_data):
            if item.startswith("sign2text-app-"):
                path = os.path.join(derived_data, item)
                print_info(f"Removing {path}")
                subprocess.run(["rm", "-rf", path])
                count += 1

        if count > 0:
            print_success(f"Cleaned {count} derived data directories")
        else:
            print_info("No derived data directories to clean")
    except Exception as e:
        print_warning(f"Error cleaning derived data: {e}")

def main():
    """Main function"""
    print_info("Starting Info.plist project integration script...")

    # Find the Xcode project
    xcode_project = find_xcode_project()
    if not xcode_project:
        print_error("Could not find an Xcode project (.xcodeproj) in the current directory")
        return 1

    print_info(f"Found Xcode project: {xcode_project}")

    # Ensure Info.plist is in the project
    if not ensure_info_plist_in_project(xcode_project):
        print_error("Failed to add Info.plist to the project")
        return 1

    # Clean derived data
    clean_derived_data()

    print_success("\nInfo.plist integration completed successfully!")
    print_info("\nNext steps:")
    print_info("1. Close Xcode completely if it's open")
    print_info("2. Open the project again")
    print_info("3. Clean the build folder (Product > Clean Build Folder)")
    print_info("4. Build and run the app")

    return 0

if __name__ == "__main__":
    sys.exit(main())
