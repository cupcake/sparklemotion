#!/bin/sh

# Example XCode build script
#
# Add it as a "Run Script" phase at the end of your app target build.
#
# Create PROJECT_ROOT/config/release with the url and key for your Sparkle Motion server:
#
# smurl=https://sparkle-motion-42.herokuapp.com
# smkey=supersecret

set -e -x

if [ $CONFIGURATION = "Debug" ]; then
    echo "This is not a release build. Skipping build packaging."
    exit
fi

. "$PROJECT_DIR/config/release"

plist=""

if [ -f "$INFOPLIST_FILE" ]; then
  plist="$INFOPLIST_FILE"
else
  if [ -f "$SRCROOT/$INFOPLIST_FILE" ]; then
    plist="$SRCROOT/$INFOPLIST_FILE"
  else
    echo "Missing version in plist"
    exit 1
  fi
fi

# get the bundle version from the plist
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $plist)

mkdir -p "$PROJECT_DIR/release"

zipname="$FULL_PRODUCT_NAME-$version.zip"
zip="$PROJECT_DIR/release/$zipname"
app="$CODESIGNING_FOLDER_PATH"

cd "$app/.."
codesign -f --resource-rules "$PROJECT_DIR/config/codesign_resources.plist" -s "Developer ID" "$FULL_PRODUCT_NAME"
rm -f "$zip"
zip -qr "$zip" "$FULL_PRODUCT_NAME"

length=$(stat -f%z "$zip")
md5=$(openssl dgst -md5 -binary "$zip" | openssl enc -base64)

url=$(curl -F "version=$version" -F "file=@$zip" -H "Content-MD5: $md5" "$smurl/upload?key=$smkey&length=$length")
url="${url?}" # strip trailing newline

if [[ $url != http* ]]; then
  echo "Upload error: $url"
  exit 1
fi

open "$smurl/?version=$version&length=$length&url=$url"
