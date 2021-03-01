#!/bin/bash

xcodebuild -project Snapyr.xcodeproj -scheme SnapyrTests -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 12,OS=14.4' test 