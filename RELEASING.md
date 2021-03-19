Releasing
=========

 1. Update the version in `SnapyrSDK.m`, `Snapyr.podspec`, `Snapyr/Info.plist` and to the next release version.
 2. Update the `CHANGELOG.md` for the impending release.
 3. `git commit -am "Prepare for release X.Y.Z."` (where X.Y.Z is the new version).
 4. `git tag -a X.Y.Z -m "Version X.Y.Z"` (where X.Y.Z is the new version).
 5. `git push && git push --tags`.
 6. `pod trunk push Snapyr.podspec`.
 7. Next, we'll create a Carthage build by running `make archive`.
 8. Create a new Github release at https://github.com/snapyrautomation/snapyr-ios-sdk/releases
     * Add latest version information from `CHANGELOG.md`
     * Upload `Snapyr.zip` from step 8 into binaries section to make available for users to download.
 9. `git push`.
