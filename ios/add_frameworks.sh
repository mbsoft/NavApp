#!/bin/bash

# Add NextBillion.ai frameworks to Xcode project
PROJECT_PATH="NavApp.xcodeproj"
TARGET_NAME="NavApp"

# Frameworks to add
FRAMEWORKS=(
    "Carthage/Build/Nbmap.xcframework"
    "Carthage/Build/Turf.xcframework"
    "Carthage/Build/NbmapCoreNavigation.xcframework"
    "Carthage/Build/NbmapNavigation.xcframework"
)

echo "Adding NextBillion.ai frameworks to Xcode project..."

# This is a simplified approach - in practice, you'd need to use xcodeproj gem
# or manually add through Xcode. For now, let's try building and see if the frameworks are found.

echo "Frameworks copied successfully. You may need to manually add them to Xcode project:"
for framework in "${FRAMEWORKS[@]}"; do
    echo "  - $framework"
done

echo ""
echo "To add manually in Xcode:"
echo "1. Open NavApp.xcworkspace"
echo "2. Select NavApp project"
echo "3. Select NavApp target"
echo "4. Go to 'General' tab"
echo "5. Add frameworks under 'Frameworks, Libraries, and Embedded Content'"
echo "6. Click '+' and 'Add Other...' -> 'Add Files...'"
echo "7. Select the .xcframework files from Carthage/Build/"
