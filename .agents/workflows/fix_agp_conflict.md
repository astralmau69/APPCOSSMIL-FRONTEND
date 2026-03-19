---
description: How to automatically fix AGP (Android Gradle Plugin) version conflicts in Flutter/Android projects when a newer package dependency breaks the build.
---
# Fix AGP Version Conflicts

When you encounter an error during `flutter run` or `flutter build` that looks like:
> `Dependency 'androidx.core:core-ktx:XXX' requires Android Gradle plugin Y.Y.Y or higher.`
> `This build currently uses Android Gradle plugin Z.Z.Z.`

Follow these steps to safely resolve the conflict:

1. **Identify the required AGP version.** From the error output, find the "requires Android Gradle plugin Y.Y.Y" string.
2. **Find the current AGP declaration.** Open the `android/settings.gradle` or `android/settings.gradle.kts` file. Locate the plugins block matching:
   `id("com.android.application") version "Z.Z.Z"` or `id 'com.android.application' version 'Z.Z.Z'`.
3. **Check Gradle Wrapper compatibility.** Open `android/gradle/wrapper/gradle-wrapper.properties` and verify `distributionUrl`. 
   - Note: AGP versions usually require a specific minimum Gradle version (e.g., AGP 8.9 requires Gradle 8.11+). If the current Gradle is too low, you must also upgrade the distribution URL to match the AGP compatibility matrix.
4. **Update the AGP Version.** Replace `Z.Z.Z` with `Y.Y.Y` (the required version) in `android/settings.gradle` / `android/settings.gradle.kts`.
5. **Clear caches (Optional).** Normally, executing `flutter clean` makes sure everything forces a reinstall of the newer plugins.
6. **Rebuild.** Run `flutter build apk --debug` to verify the build process correctly downloads the new AGP and passes the metadata checks.
