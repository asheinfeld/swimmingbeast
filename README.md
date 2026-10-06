# SwimmingBeast

Pool-swim tracking for Apple Watch with an iPhone companion. The watch records each length, along with its split, pace, and the stroke Apple Watch detected. Tap any length to fix a wrong stroke. The iPhone shows your swim history, a per-length table, and your stroke mix.

- **Pool only.** 25 yd, 25 m, or 50 m.
- **SwiftUI only.** Requires iOS 17+ and watchOS 10+.
- **No accounts and no cloud.** HealthKit is the source of truth for time and distance. Stroke corrections are stored on the device.

## Repository layout

```
project.yml                 XcodeGen spec (source of truth for the Xcode project)
SwimmingBeast.xcodeproj     Generated from project.yml; committed so it opens directly
Packages/SwimKit/           Local Swift package
  Sources/SwimCore/         Models, pace math, stroke enums, override logic. Imports only Foundation.
  Sources/SwimHealth/       HealthKit session + history, SwiftData override store, WatchConnectivity
  Tests/                    XCTest suites (run with `swift test`, including on Linux)
SwimWatch/                  watchOS app target: setup → active (controls / metrics / lengths) → summary
SwimPhone/                  iOS app target: history → workout detail, settings
Shared/                     SwiftUI pieces compiled into both apps (stroke chip, mix bar, stroke picker, sample badge)
```

## Architecture

```
 SwimWatch (watchOS app)          SwimPhone (iOS app)
   SetupView                        HistoryView ─▶ WorkoutDetailView
   ActiveSessionView                SettingsView
   SummaryView                      HistoryStore (merges sources, applies overrides)
        │                                 │
        ▼                                 ▼
 ┌──────────────────────── SwimHealth ───────────────────────────┐
 │ SwimSessionServing (protocol)    SwimHistoryProviding (proto) │
 │   HealthKitSwimSession             HealthKitSwimHistory       │
 │   PreviewSwimSession (simulated)   SampleSwimHistory          │
 │ SwiftDataStrokeOverrideStore     SwimConnectivity (WC)        │
 └───────────────────────────────────────────────────────────────┘
        │
        ▼
 ┌──────────────────────── SwimCore ─────────────────────────────┐
 │ SwimWorkout, Length, StrokeStyle, StrokeSource, PoolLength    │
 │ Pace / SwimFormat, LengthReconciler, StrokeOverrideMetadata   │
 │ StrokeOverrideStoring (protocol), SampleData                  │
 └───────────────────────────────────────────────────────────────┘
```

### SwimCore

These are plain value types with no UI or HealthKit dependency.

- `SwimWorkout` stores `startedAt`, `endedAt`, `poolLength` (a `Measurement<UnitLength>`), `lengths`, and `healthKitUUID`. Everything else is computed from those: `distance` (number of lengths × pool length), `swimmingDuration`, `elapsedDuration`, `averagePace` (excludes rest), `strokeMix`, and `fastestLength`.
- `Length` stores `index`, `duration`, `stroke`, `strokeSource` (`.healthKit` or `.user`), and `splitPace` (a `Measurement<UnitSpeed>`).
- `StrokeStyle(healthKitRawValue:)` maps `HKSwimmingStrokeStyle` raw values without importing HealthKit. `kickboard` has no case of its own, so those lengths show up as `.unknown` and you can relabel them.
- `LengthReconciler` rebuilds the length list each time HealthKit delivers lap events. Lengths keep their IDs and your overrides even if HealthKit later refines a lap.
- `SwimFormat` formats pace per 100 (for example `1:45 /100m`), splits, and distances the same way on both devices.

### SwimHealth

- **`SwimSessionServing`** is the protocol the watch UI talks to. It defines `state`, `poolLength`, `lengths`, `heartRate`, `requestAuthorization()`, `start(poolLength:)`, `pause()`, `resume()`, `overrideStroke(lengthId:style:)`, `endAndSave()`, and `reset()`.
- **`HealthKitSwimSession`** runs an `HKWorkoutSession` with an `HKLiveWorkoutBuilder`. The workout is configured as swimming, indoor, in a pool, with `lapLength` set to the pool you chose. During a pool swim the system emits one `.lap` event per length, tagged with `HKMetadataKeySwimmingStrokeStyle`. Those events are turned into `[Length]`. When you end the swim, `endAndSave()` ends collection, writes your overrides into the workout metadata (`com.swimmingbeast.strokeOverrides`), finishes the workout, and returns a `SwimWorkout` with its HealthKit UUID.
- **`PreviewSwimSession`** is a simulated session that generates a new length every few seconds. It's used for SwiftUI previews, unit tests, and the watch simulator, which can't detect swimming. Its `isSimulated` flag is always true, and the UI then shows a **Sample data** badge.
- **`HealthKitSwimHistory`** queries swimming workouts and keeps only pool swims. It reads the lap length and lap events, then applies any overrides stored in the workout metadata.
- **`SwiftDataStrokeOverrideStore`** stores `StrokeOverrideRecord` entries keyed by `(workoutKey, lengthIndex)`. `workoutKey` is the HealthKit UUID when there is one. Keys use the length index rather than `Length.id` because the index stays the same across HealthKit re-queries.
- **`SwimConnectivity`** (optional) uses WatchConnectivity in two directions. The watch sends the just-finished workout to the iPhone with `transferUserInfo`, so it appears before HealthKit syncs. The iPhone sends the default pool length to the watch with `updateApplicationContext`.

### Who wins

| Data | Source of truth |
| --- | --- |
| Time, distance, number of lengths, heart rate | HealthKit |
| Stroke per length | Your local override if there is one. Otherwise an override from the watch, saved in the workout metadata. Otherwise HealthKit's detected stroke. |

## Running it

You need a Mac with **Xcode 15.4 or later** (Xcode 16 recommended), an Apple ID or paid developer team, and for real swims an **Apple Watch Series 2 or later** paired with an iPhone.

1. Open the project:

   ```bash
   open SwimmingBeast.xcodeproj
   ```

   If you edit `project.yml`, regenerate the project with [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`):

   ```bash
   xcodegen generate
   ```

2. **Set your team.** Select the project, then for both the **SwimPhone** and **SwimWatch** targets go to *Signing & Capabilities* and choose your Team. You can also set `DEVELOPMENT_TEAM` in `project.yml` and regenerate. The placeholder bundle IDs (`com.swimmingbeast.app` and `com.swimmingbeast.app.watchkitapp`) must be unique to your team. If Xcode says they're taken, change both, and keep `WKCompanionAppBundleIdentifier` in `project.yml` matching the iPhone ID.
3. **HealthKit capability.** Both targets already include the HealthKit entitlement (`SwimPhone/SwimPhone.entitlements`, `SwimWatch/SwimWatch.entitlements`). With automatic signing, Xcode registers it on your App IDs.
4. **Run on devices.** Pick the **SwimPhone** scheme with your iPhone and click Run. Installing the iPhone app also installs the embedded watch app. To debug the watch directly, pick the **SwimWatch** scheme with your paired Apple Watch as the destination.
5. **Grant Health permissions.** The first time you tap **Start Swim**, the watch asks for Health access. The first time History loads, the iPhone asks too. If you denied access, you can change it in the Health app (*Profile › Apps › SwimmingBeast*) or in watch *Settings › Health › Apps*.

### Simulator

- **Watch simulator.** The app uses `PreviewSwimSession`, so lengths are generated rather than detected, they are marked "Sample data", and nothing is saved to Health.
- **iPhone simulator.** "Show sample workouts" is on by default, so History has labeled sample swims to explore. Real HealthKit swims (if any) are listed alongside them. You can turn samples off in Settings.

### On a real swim

- Water Lock turns on when the swim starts. To change a stroke, unlock by turning the Digital Crown (usually while resting at the wall), swipe to **Lengths**, tap a length, and pick the stroke.
- Lengths are detected by Apple Watch when you push off the wall. Rest at the wall to end a set.

### Tests

The core logic (models, pace math, stroke mapping, reconciliation, override encoding, and the simulated session) is covered by the package tests:

```bash
cd Packages/SwimKit
swift test
```

These tests also run from the **SwimPhone** scheme in Xcode (⌘U).

## Known limitations (v1)

- Pool swims only. There's no open water, GPS, coaching, complications, accounts, or sync beyond the watch-to-iPhone handoff.
- If saving fails after the session ends (for example, Health permission was revoked mid-swim), the summary shows an error and the swim isn't kept.
- There's no workout recovery after the watch app crashes. HealthKit supports this through `HKHealthStore.recoverActiveWorkoutSession`, which would be the next step.
- Stroke corrections made on the iPhone stay on that iPhone. They aren't written back to HealthKit, because saved workouts can't be changed.
- App icons are empty placeholders.
