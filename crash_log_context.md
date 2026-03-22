# Crash Log — Hot Restart (2026-03-21 23:26)

## Context
After applying performance optimizations (Round 3), the app lost connection to device during hot restart.

## Log Output
```
W/WindowOnBackDispatcher(14866): sendCancelIfRunning: isInProgress=false callback=androidx.activity.OnBackPressedDispatcher$Api34Impl$createOnBackAnimationCallback$1@541b5f8

Performing hot restart...
Restarted application in 1,681ms.

V/MediaPlayer-JNI(14866): native_setup
V/MediaPlayerNative(14866): constructor
V/MediaPlayerNative(14866): setListener
V/MediaPlayer-JNI(14866): get_session_id()
V/MediaPlayer-JNI(14866): setParameter: key 1400

W/WindowOnBackDispatcher(14866): sendCancelIfRunning: isInProgress=false callback=...@541b5f8

Lost connection to device.
```

## Analysis
- The app restarted successfully (1,681ms) but then **lost connection to device**
- `MediaPlayer-JNI` init lines suggest the splash screen audio player initialized
- No Flutter framework error — the crash appears to be at the native/connection level
- `WindowOnBackDispatcher` warnings are cosmetic (Android 14 predictive back API)
- Exit code: 1

## Possible Causes
1. Device disconnected or USB timeout during hot restart
2. MediaPlayer native crash during audio init on splash
3. Memory pressure causing OOM kill on the app process

## Changes Applied Before This Crash
- `OptimizedPressButton`: removed FadeTransition → pure ScaleTransition
- `AnimatedPressButton`: same fix + removed Tween allocation in build()
- `regional_screen`: AnimatedCrossFade → conditional, avatar 120→80px, boxShadow removed
- `specialty_screen`: stagger delays capped, breadcrumbs/headers instant
- `schedule_screen`: delays reduced 50%
- `home_screen`: animation budget reduced 40%
- `beneficiary_selector_modal`: shrinkWrap removed
- `splash_screen`: FadeTransition glow → AnimatedBuilder with color alpha
- `app.dart`: DefaultTextStyle with decoration:none
- `app_theme.dart`: TextDecoration.none in TextTheme
- `AndroidManifest.xml`: enableOnBackInvokedCallback=true

## Status
- `flutter analyze` → 0 issues
- `flutter test` → 2/2 passed
- Runtime: needs re-run to confirm stability
