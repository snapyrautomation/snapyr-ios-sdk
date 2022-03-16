#!/bin/bash
echo "Creating directory 'builtframework' where XCFramework will be stored"
mkdir builtframework
mkdir builtframework/ .archives

echo "Archiving for iPhone Simulator"
rm -r builtframework/.archives
xcodebuild archive \
 -scheme Snapyr \
 -archivePath builtframework/.archives/Snapyr-iphonesimulator.xcarchive \
 -sdk iphonesimulator \
 SKIP_INSTALL=NO

echo "Archiving for iOS"
xcodebuild archive \
 -scheme Snapyr \
 -archivePath builtframework/.archives/Snapyr-iphoneos.xcarchive \
 -sdk iphoneos \
 SKIP_INSTALL=NO

echo "Archiving for macOS"
xcodebuild archive \
 -scheme Snapyr \
 -archivePath builtframework/.archives/Snapyr-macosx.xcarchive \
 -sdk macosx \
 SKIP_INSTALL=NO

echo "Archiving for Apple TV Simulator"
xcodebuild archive \
 -scheme Snapyr \
 -archivePath builtframework/.archives/Snapyr-appletvsimulator.xcarchive \
 -sdk appletvsimulator \
 SKIP_INSTALL=NO

echo "Archiving for Apple tvOS"
xcodebuild archive \
 -scheme Snapyr \
 -archivePath builtframework/.archives/Snapyr-appletvos.xcarchive \
 -sdk appletvos \
 SKIP_INSTALL=NO

echo "Combining frameworks and creating an XCFramework"
rm -r builtframework/Snapyr.xcframework
xcodebuild -create-xcframework \
 -framework builtframework/.archives/Snapyr-iphonesimulator.xcarchive/Products/Library/Frameworks/Snapyr.framework \
 -framework builtframework/.archives/Snapyr-iphoneos.xcarchive/Products/Library/Frameworks/Snapyr.framework \
 -framework builtframework/.archives/Snapyr-macosx.xcarchive/Products/Library/Frameworks/Snapyr.framework \
 -framework builtframework/.archives/Snapyr-appletvsimulator.xcarchive/Products/Library/Frameworks/Snapyr.framework \
 -framework builtframework/.archives/Snapyr-appletvos.xcarchive/Products/Library/Frameworks/Snapyr.framework \
 -output builtframework/Snapyr.xcframework

rm -r builtframework/.archives

open builtframework
