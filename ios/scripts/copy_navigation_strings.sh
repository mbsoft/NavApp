#!/bin/bash

# Script to copy Navigation.strings to the NbmapNavigation framework bundle
# This ensures the string override persists after clean builds

set -e

# Get the build products directory from Xcode environment variables
BUILT_PRODUCTS_DIR="${BUILT_PRODUCTS_DIR}"
PRODUCT_NAME="${PRODUCT_NAME}"

if [ -z "$BUILT_PRODUCTS_DIR" ] || [ -z "$PRODUCT_NAME" ]; then
    echo "Error: Required environment variables not set"
    echo "BUILT_PRODUCTS_DIR: $BUILT_PRODUCTS_DIR"
    echo "PRODUCT_NAME: $PRODUCT_NAME"
    exit 1
fi

# Path to the source Navigation.strings file
SOURCE_FILE="${SRCROOT}/NavApp/Resources/Navigation.strings"

# Path to the destination in the framework bundle
FRAMEWORK_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Frameworks/NbmapNavigation.framework"
DEST_DIR="${FRAMEWORK_PATH}/en.lproj"
DEST_FILE="${DEST_DIR}/Navigation.strings"

echo "Copying Navigation.strings to framework bundle..."
echo "Source: $SOURCE_FILE"
echo "Destination: $DEST_FILE"

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file not found: $SOURCE_FILE"
    exit 1
fi

# Check if framework exists
if [ ! -d "$FRAMEWORK_PATH" ]; then
    echo "Error: Framework not found: $FRAMEWORK_PATH"
    exit 1
fi

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Copy the file
cp "$SOURCE_FILE" "$DEST_FILE"

echo "Successfully copied Navigation.strings to framework bundle"

