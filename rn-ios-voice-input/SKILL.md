---
name: rn-ios-voice-input
description: General constraints and pitfalls for voice and recording in React Native on iOS, reusable across projects. Recommends react-native-audio-recorder-player; document is iOS-focused and explains how Android-related issues in shared code affect iOS.
---

# React Native voice and recording constraints (iOS)

When implementing voice input (record → stop → upload or process via returned path) in React Native on iOS, follow the constraints below to avoid "file not found", white screen/crash, start succeeding but stop reporting nil, or launch crash.

**Recommended library**: `react-native-audio-recorder-player` (constraints below refer to its `startRecorder` / `stopRecorder`). If using another library, verify path and native semantics against that library's docs.

---

## 1. Recording path on iOS: pass filename only, not full path

**Constraint**: On iOS the library treats `startRecorder(path, ...)` as a path **relative to the Caches directory**, built with `FileManager.default.urls(for: .cachesDirectory)...appendingPathComponent(path)`. Passing an absolute path or `file://` URL yields a wrong path, write/read fails, and upload can report "couldn't be opened".

**Rules**:
- **Don't**: Build a full path or `file://` URL from `RNFS.CachesDirectoryPath` plus filename and pass it to `startRecorder` on iOS.
- **Do**: On iOS pass only a **bare filename** (e.g. `'voice.wav'`); use the `file://` URL returned by `stopRecorder()` as the `uri` for upload or file read.

**Principle**: When passing paths across JS/native, follow the library's semantics; do not assume "absolute path is safer".

---

## 2. Use runtime enums only, not type aliases as values

**Constraint**: In the library's TypeScript definitions, `AVEncodingType` is a **type alias** (no runtime value); `AVEncodingOption` is the exported **enum**. Writing `AVEncodingType.aac` compiles but at runtime is `undefined.aac`, throwing on module load or first use and causing white screen/crash.

**Rules**:
- **Don't**: Use `AVEncodingType.aac`, `AVEncodingType.lpcm`, etc. as `AVFormatIDKeyIOS` or anywhere a value is required.
- **Do**: Use only `AVEncodingOption.*` (e.g. `AVEncodingOption.aac`, `AVEncodingOption.wav`); when needed use **actually exported enums** such as `AVEncoderAudioQualityIOSType`, `AVLinearPCMBitDepthKeyIOSType`, and confirm names from the library's index before importing.

**Principle**: A "Type" in third-party libs is often type-only; pass values using symbols that exist at runtime (enums/constants).

---

## 3. Wrong Android enum names in shared config break the whole module (effect on iOS)

**Constraint**: The library is cross-platform; the same recording config often includes both iOS and Android keys (e.g. `OutputFormatAndroid`, `AudioEncoderAndroid`). The library actually exports **`OutputFormatAndroidType`** and **`AudioEncoderAndroidType`** (with `Type` suffix). Using `OutputFormatAndroid` / `AudioEncoderAndroid` gives `undefined` on import; accessing `OutputFormatAndroid.DEFAULT` at module top level throws.

**Effect on iOS**: That throw happens at **module load time** (when the hook or wrapper that uses the library is imported). The whole module exports as `undefined`. So **on iOS** callers see "Cannot read property 'useAudioRecorder' of undefined" (or whatever hook name you export). Symptoms: "app crashes as soon as record is tapped" or "screen goes white when entering the recording screen". Root cause is wrong Android enum names in shared code; unrelated to device/simulator or mic permission.

**Rules**:
- **Don't**: Use `OutputFormatAndroid` or `AudioEncoderAndroid` (no `Type` suffix) in recording config or in a module that wraps the library.
- **Do**: Use `OutputFormatAndroidType.DEFAULT`, `AudioEncoderAndroidType.DEFAULT`; confirm actual export names from the library's `.d.ts` or `index.js`.

**Principle**: With cross-platform libs, a wrong symbol for any platform can prevent the whole module from loading; if a hook is undefined on iOS, check for wrong enum/constant names from other platforms in the same file.

---

## 4. Format and LPCM settings on iOS: wav vs lpcm, parameters must be complete

**Constraint**:
- On iOS the library maps the string `"lpcm"` incorrectly to `kAudioFormatAppleIMA4` (not LinearPCM), conflicting with LPCM settings and often causing `AVAudioRecorder` init failure or the recorder to be released by the system—manifesting as start succeeding but stop reporting "It is already nil." or start throwing "Error occured during recording".
- With LPCM, missing or wrong `AVLinearPCMBitDepthKey` etc. also causes init failure; LPCM is less stable on x86_64 simulator.

**Rules**:
- **Don't**: Use only `AVEncodingOption.lpcm` without full LPCM parameters when you need WAV/LinearPCM, or rely on the library's internal defaults.
- **Do**: For WAV use **`AVEncodingOption.wav`** (library maps it to `kAudioFormatLinearPCM`) and set explicitly: `AVLinearPCMBitDepthKeyIOS: 16`, `AVLinearPCMIsBigEndianKeyIOS: false`, `AVLinearPCMIsFloatKeyIOS: false`; use `.wav` for filename and extension. For AAC use `AVEncodingOption.aac`; no LPCM keys needed.

**Principle**: Format key, native mapping, and all keys required for that format must be valid and complete; prefer enum values the library maps correctly (e.g. `wav`).

---

## 5. Typical start/stop recording errors

| Symptom | Meaning / common cause | Check order |
|---------|------------------------|------------|
| `startRecorder` succeeds, `stopRecorder` reports **"Failed to stop recorder. It is already nil."** | Native recorder was never created or was released; often format/params mismatch (§4). | 1) Switch to `AVEncodingOption.wav` and set LPCM params; 2) Confirm mic permission; 3) Test on device. |
| **"Cannot read property 'useAudioRecorder' of undefined"** (or any hook name undefined) at module load | Module threw at import, export is undefined. Often §2 (type alias used as value) or §3 (wrong Android enum names). | Ensure all symbols imported from the library in that module are actual exported enums (including Android `*Type` suffix). |
| **"Error occured during recording"** (startRecorder catch) | `AVAudioRecorder` init or `record()` failed; recorder not created; stop will then hit "already nil". | Same root as "already nil": fix format and LPCM params, then permission, then test on device. |

**Principle**: "Already nil" and "Error occured during recording" usually share the same root cause (native never created or held the recorder); fix format and enum names first, then permission and environment.

---

## 6. Do not "warm up" mic permission with a fake record at app launch

**Constraint**: Calling `startRecorder()` then immediately `stopRecorder()` in root component or `App.tsx` `useEffect` to "request mic permission early" can trigger null pointer or exception during `AVAudioRecorder` init or underlying codec registration on some setups (especially iOS x86_64 simulator), causing **launch crash**, possibly intermittent.

**Rules**:
- **Don't**: Run one start/stop automatically on mount to "silently request permission".
- **Do**: Call `startRecorder` when the user first taps "start recording"; if you need permission earlier, use the system or a permission library API, not a fake recording flow.

**Principle**: Do not trigger native recording init at a time not tied to user action; avoid unpredictable crash on the launch path.

---

## 7. Disable system auto-lock during recording (recommendation)

**Constraint**: While recording the user may not touch the screen; if auto-lock is not disabled, the device may sleep/lock by policy, which can trigger audio session interruption or process suspension, so recording stops and data is not written or is lost.

**Rules**:
- **Don't**: Leave default behavior so the system locks after idle during recording.
- **Do**: From `startRecorder` until `stopRecorder` completes, use the system API to disable idle sleep/lock (e.g. iOS `idleTimerDisabled`, or a keep-awake capability on the RN side); after `stopRecorder` or cancel, restore the previous behavior so the app does not keep the device awake indefinitely.

**Principle**: Explicitly disable auto-lock for the recording lifecycle and restore afterward to avoid interruption and data loss.

---

## 8. If JS changes to recording logic don't take effect: check Release vs Debug and rebuild

**Constraint**: With Xcode **Release**, the JS bundle is usually baked into the app and Metro hot reload does not update the running bundle; if you still see old behavior or old errors after changing recording logic, you may need a full rebuild.

**Rule**: Use **Debug** during development; if using Release, rebuild the app after JS changes and verify.
