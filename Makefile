XC_ARGS := -project Snapyr.xcodeproj GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES
IOS_XCARGS := $(XC_ARGS) -destination "platform=iOS Simulator,name=iPhone 12" -sdk iphonesimulator
TVOS_XCARGS := $(XC_ARGS) -destination "platform=tvOS Simulator,name=Apple TV"
MACOS_XCARGS := $(XC_ARGS) -destination "platform=macOS"
XC_BUILD_ARGS := -scheme Snapyr ONLY_ACTIVE_ARCH=NO
XC_TEST_ARGS := GCC_GENERATE_TEST_COVERAGE_FILES=YES SWIFT_VERSION=5.0 RUN_E2E_TESTS=$(RUN_E2E_TESTS) WEBHOOK_AUTH_USERNAME=$(WEBHOOK_AUTH_USERNAME)

bootstrap:
	.buildscript/bootstrap.sh

lint:
	pod lib lint --allow-warnings

# NOTE: as of 2022-10-06 we no longer use/support carthage. We now use/support XCFrameworks instead.
# Use `make archive` instead to build the XCFramework.
# Leaving this here temporarily in case it's needed for some reason; will remove in a future update.
# At present running `make carthage` will encounter errors if run from an arm64 machine (i.e. M1 or newer
# Mac). There are hacks available to address this but not bothering to implement those now - see
# https://github.com/Carthage/Carthage/blob/master/Documentation/Xcode12Workaround.md#workaround-script
carthage:
	export XCODE_XCCONFIG_FILE=$(PWD)/tmp.xcconfig && carthage build --platform ios --no-skip-current

archive:
	./buildxcframework.sh

clean-ios:
	set -o pipefail && xcodebuild $(IOS_XCARGS) -scheme Snapyr clean | xcpretty

clean-tvos:
	set -o pipefail && xcodebuild $(TVOS_XCARGS) -scheme Snapyr clean | xcpretty

clean-macos:
	set -o pipefail && xcodebuild $(MACOS_XCARGS) -scheme Snapyr clean | xcpretty

clean: clean-ios

build-ios:
	set -o pipefail && xcodebuild $(IOS_XCARGS) $(XC_BUILD_ARGS) | xcpretty

build-tvos:
	set -o pipefail && xcodebuild $(TVOS_XCARGS) $(XC_BUILD_ARGS) | xcpretty

build-macos:
	set -o pipefail && xcodebuild $(MACOS_XCARGS) $(XC_BUILD_ARGS) | xcpretty

build: build-ios

test-ios:
# 	xcodebuild test $(IOS_XCARGS) -scheme SnapyrTests $(XC_TEST_ARGS)
	@set -o pipefail && xcodebuild test $(IOS_XCARGS) -scheme SnapyrTests $(XC_TEST_ARGS) | xcpretty --report junit

test-tvos:
	@set -o pipefail && xcodebuild test $(TVOS_XCARGS) -scheme SnapyrTests $(XC_TEST_ARGS) | xcpretty --report junit

test-macos:
	@set -o pipefail && xcodebuild test $(MACOS_XCARGS) -scheme SnapyrTests $(XC_TEST_ARGS) | xcpretty --report junit

test: test-ios

xctest:
	xctool $(IOS_XCARGS) -scheme SnapyrTests $(XC_TEST_ARGS) run-tests -sdk iphonesimulator

.PHONY: bootstrap dependencies lint carthage archive build test xctest clean
