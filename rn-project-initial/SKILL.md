---
name: rn-project-initial
description: React Native (iOS) project setup, version pinning, CocoaPods, nvm/rvm, Xcode 16.3 compatibility, react-native-svg, audio recorder file paths. Apply when creating or building RN apps, running pod install, or fixing iOS/RN dependency issues.
---

# React Native Project Build Guidelines

When developing React Native projects, follow these guidelines.

## 1 Principles to follow

1. **Pin toolchain versions.** Use a fixed, known-good combination of Node, Ruby, React, React Native, Xcode, and CocoaPods. Avoid ad-hoc or "latest" mixes to prevent endless dependency and compatibility issues.

2. **Use nvm and rvm when the environment does not match.** Assume the user has nvm and rvm available; use them to switch Node and Ruby to the required versions. If they are not installed, instruct the user to install them rather than changing the required versions.

3. **Prefer `@react-native-community/cli` for new projects.** Use `npx @react-native-community/cli init ...` to create the app unless the user explicitly requests Expo.

4. **Add dependencies carefully.** Before adding a new dependency, check for version conflicts in `package.json` and compatibility with the current Node, Ruby, React Native, and Xcode versions. Resolve or avoid conflicts before introducing the dependency.

5. **Do not rely on "just downgrade" or "just upgrade the system."** When facing hard compatibility issues, do not assume that downgrading a random package will fix it, and do not assume the user will upgrade Xcode or macOS. Prefer changing React Native and related library versions to match the existing environment.

6. **Remember React Native is not a full native environment.** Some native APIs (e.g. Node's `Buffer`, or assumptions about file paths) may be unavailable or different in the JS bridge, Workers, or simulators. Check the target runtime (iOS/Android, simulator/device, Cloudflare Workers, etc.) and use only APIs and patterns that are valid there.

## 2 Recommended Version Combinations

### Verified Working Configuration (2026-02)
- **Xcode**: 16.3
- **Node.js**: 20.19.4 (via nvm)
- **Ruby**: 2.7.1 (via rvm)
- **CocoaPods**: 1.15.2
- **React Native**: 0.76.9+
- **React**: 18.3.1

### Critical Version Notes
- **React Native 0.76.6 and below** are incompatible with Xcode 16.3 due to `std::char_traits<unsigned char>` compilation errors
- **React Native 0.76.9+** includes the fix for Xcode 16.3 compatibility
- Always use React Native 0.76.9 or higher when working with Xcode 16.3

## 3 Best Practices

### Project Creation
- Use `npx @react-native-community/cli init ProjectName --version 0.76.9` to create project templates instead of `expo`, as we need to run standalone Native Apps rather than in Expo GO
- Specify React Native version explicitly to ensure compatibility

### Environment Management
- Assume user machines have nvm and rvm installed. Prioritize using these tools to ensure stable ruby and node environments. Proactively switch versions when incompatible
- After using rvm to switch versions, assume CocoaPods is already installed. Just check if the version meets requirements instead of installing directly
- **Important**: Use `bash -c "source ~/.rvm/scripts/rvm && rvm use 2.7.1 && ..."` to ensure rvm is properly loaded in shell commands
- Always set `export LANG=en_US.UTF-8` before running CocoaPods commands to avoid encoding errors

### Version Compatibility Strategy
- Xcode and system version updates are high-cost, place them at lowest priority. Resolve compatibility issues by switching react, react-native, and third-party library versions instead of suggesting system upgrades or waiting for community updates
- For the ios folder in project templates created by `@react-native-community/cli`, directly delete the Gemfile and use ruby and cocoapods from rvm
- When encountering compilation errors, first check React Native version compatibility with current Xcode version

### Compilation and Debugging
- Prioritize using command line to run and view logs (npx react-native run-ios + xcodebuild + xcrun simctl) instead of launching Xcode IDE
- When encountering Xcode compilation issues caused by third-party library code, prioritize checking pod install logs, npm logs, and dependency relationships and version compatibility between libraries

## 4 Common Issues and Solutions

### Issue 1: Building iOS app with Xcode 16.3
**Scenario**: Building or running the React Native iOS app when the environment uses Xcode 16.3 (or when you introduce or upgrade Xcode to 16.3).

**Constraints**: Xcode 16.3 removed the base template for `std::char_traits<unsigned char>`. React Native below 0.76.9 still uses it, so the iOS build fails with `implicit instantiation of undefined template 'std::char_traits<unsigned char>'`. Do not assume an older RN version is compatible with the latest Xcode.

**Correct practice**:
- **Don't**: Use React Native 0.76.6 or lower with Xcode 16.3.
- **Do**: Use React Native 0.76.9 or higher. Align all `@react-native/*` packages to the same version (e.g. `0.76.9` for `babel-preset`, `eslint-config`, `metro-config`, `typescript-config`). Run `npm install`, delete `ios/Podfile.lock`, then run `pod install` in `ios/`.

**Principle**: Match React Native and related packages to the Xcode version in use; prefer upgrading RN and deps over upgrading or changing Xcode when resolving compatibility.

### Issue 2: Running CocoaPods (pod install)
**Scenario**: Running CocoaPods in this project (e.g. `pod install`, or any script/CI that invokes pod).

**Constraints**: Without a UTF-8 locale, CocoaPods can raise `Unicode Normalization not appropriate for ASCII-8BIT`. Do not run pod in a shell that has not set a UTF-8 locale.

**Correct practice**:
- **Don't**: Run `pod install` (or other pod commands) without ensuring UTF-8.
- **Do**: Set `export LANG=en_US.UTF-8` before any pod command, or include it in scripts/CI that run pod.

**Principle**: Ensure a UTF-8 environment for CocoaPods to avoid encoding-related failures.

### Issue 3: Running Ruby / CocoaPods from scripts or non-interactive shells
**Scenario**: Invoking `pod install` or other Ruby-dependent commands from a script, Makefile, or non-interactive shell (e.g. CI, IDE runner, or one-off `bash -c "..."`).

**Constraints**: RVM is not loaded by default in subshells or scripts, so `rvm use 2.7.1` may have no effect and the wrong Ruby (or no rvm) is used, leading to wrong CocoaPods or Ruby version errors.

**Correct practice**:
- **Don't**: Assume RVM is already loaded when running commands in a script or `bash -c`.
- **Do**: Run Ruby/pod commands via bash with explicit RVM sourcing, e.g. `bash -c "source ~/.rvm/scripts/rvm && rvm use 2.7.1 && pod install"`.

**Principle**: In non-interactive contexts, explicitly load the version manager (e.g. RVM) before switching versions or running version-sensitive commands.

### Issue 4: Using react-native-svg with React Native 0.76.x
**Scenario**: Adding, upgrading, or building a React Native 0.76.x app that uses `react-native-svg` (e.g. icons or SVG components).

**Constraints**: react-native-svg 15.13.0+ uses Yoga's `StyleLength` API, which exists only in React Native 0.78+. On RN 0.76, Yoga still exposes the old type; the removal/rename of `StyleSizeLength` causes the C++ error `No member named 'StyleSizeLength' in namespace 'facebook::yoga'`. Do not use react-native-svg 15.13+ on RN 0.76.x.

**Correct practice**:
- **Don't**: Use react-native-svg 15.13 or higher when the project is on React Native 0.76.x.
- **Do**: Pin react-native-svg to 15.12.x (e.g. `npm install react-native-svg@15.12.0`), then run `pod install` in `ios/`. Use react-native-svg 15.13+ only after upgrading to React Native 0.78+.

**Principle**: Pin native/UI libraries to versions that match the current React Native (and Yoga) API; check compatibility before upgrading such deps.

### Issue 5: Recording and uploading audio (react-native-audio-recorder-player)
**Scenario**: Implementing "record → stop → upload file at returned path" using `react-native-audio-recorder-player` (`startRecorder` / `stopRecorder`) and using the returned path as `uri` for FormData upload.

**Constraints**: On iOS the library treats the path passed to `startRecorder` as relative to the caches directory and does `appendingPathComponent`. Passing a full path (e.g. from `RNFS.CachesDirectoryPath`) yields a wrong concatenated path, so the file is written/read in the wrong place and upload reports "file not found". Do not assume JS-side path concatenation matches native file locations.

**Correct practice**:
- **Don't**: On iOS, pass a full path or `file://` URL to `startRecorder` (e.g. `file://${RNFS.CachesDirectoryPath}/gents_voice.m4a` or `${RNFS.CachesDirectoryPath}/gents_voice.m4a`).
- **Do**: On iOS pass only the **filename** (e.g. `'gents_voice.m4a'`); let native code resolve it under caches. Use the `file://` URL returned by `stopRecorder()` as the upload `uri`. On Android, a full path from `RNFS.CachesDirectoryPath` is acceptable.

**Principle**: For any native API that takes a file path, follow the library's contract (filename vs full path); do not assume path semantics across the JS/native boundary.

## Startup Script Template
Create `run-ios.sh` in the **project root** (same directory as `package.json`) with proper environment setup:

```bash
#!/bin/bash
set -e
export LANG=en_US.UTF-8

# Load rvm
if [ -f ~/.rvm/scripts/rvm ]; then
    source ~/.rvm/scripts/rvm
    rvm use 2.7.1 > /dev/null 2>&1
fi

# Start Metro if not running
if ! lsof -Pi :8081 -sTCP:LISTEN -t >/dev/null 2>&1; then
    npx react-native start &
    sleep 5
fi

# Build and run
npx react-native run-ios --no-packager
```
