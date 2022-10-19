Releasing
=========

1. Create a new branch called `release/X.Y.Z`
1. Update the version in `SnapyrSDK.m` and `Snapyr.podspec` to the next release version.
1. In Xcode, open the Build Settings for theh `Snapyr` target, and update the `Marketing Version` value to the next release version.
1. Update the `CHANGELOG.md` for the impending release.
1. `git commit -am "Prepare for release X.Y.Z."` (where X.Y.Z is the new version).
1. `git tag -a X.Y.Z -m "Version X.Y.Z"` (where X.Y.Z is the new version).
1. `git push && git push --tags`.
1. `pod trunk push Snapyr.podspec`.
1. Next, we'll create an XCFramework build by running `make archive`.
1. Create a new Github release at https://github.com/snapyrautomation/snapyr-ios-sdk/releases
     * Add latest version information from `CHANGELOG.md`
     * Upload `Snapyr.xcframework.zip` from the previous step into the binaries section to make available for users to download.
1. Merge `release/X.Y.Z` back to the main branch
1. Run github workflow from Actions page manually setting Version to X.Y.Z
