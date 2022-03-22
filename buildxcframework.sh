#!/bin/bash
echo "Creating directory 'builtframework' where XCFramework will be stored"
mkdir builtframework/.archives

rm -r builtframework/Snapyr.xcframework.zip
rm -r builtframework/Snapyr.xcframework

echo "Archiving for iPhone Simulator"
rm -r builtframework/.archives
xcodebuild archive \
 -quiet \
 -scheme Snapyr \
 -archivePath builtframework/.archives/Snapyr-iphonesimulator.xcarchive \
 -sdk iphonesimulator \
 SKIP_INSTALL=NO

echo "Archiving for iOS"
xcodebuild archive \
 -quiet \
 -scheme Snapyr \
 -archivePath builtframework/.archives/Snapyr-iphoneos.xcarchive \
 -sdk iphoneos \
 SKIP_INSTALL=NO

echo "Archiving for macOS"
xcodebuild archive \
 -quiet \
 -scheme Snapyr \
 -archivePath builtframework/.archives/Snapyr-macosx.xcarchive \
 -sdk macosx \
 SKIP_INSTALL=NO

echo "Archiving for Apple TV Simulator"
xcodebuild archive \
 -quiet \
 -scheme Snapyr \
 -archivePath builtframework/.archives/Snapyr-appletvsimulator.xcarchive \
 -sdk appletvsimulator \
 SKIP_INSTALL=NO

echo "Archiving for Apple tvOS"
xcodebuild archive \
 -quiet \
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
 
cd builtframework


zip -vr Snapyr.xcframework.zip Snapyr.xcframework/

rm -r .archives
rm -r builtframework/Snapyr.xcframework

echo "Archive finished"
