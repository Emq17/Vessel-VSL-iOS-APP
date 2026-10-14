# VSL — Vessel

**Native iOS health, fitness, and productivity app**

Built with **Swift, SwiftUI, and HealthKit**, VSL brings workout interval analysis, sleep-stage exploration, health tracking, focused planning, and journaling into one minimalist interface.

## Screenshots

Add your own screenshots to a `screenshots/` folder at the repository root, then use these filenames:

<p align="center">
  <img src="screenshots/performance.png" width="180" alt="Performance screen">
  <img src="screenshots/sleep.png" width="180" alt="Sleep screen">
  <img src="screenshots/focus.png" width="180" alt="Focus screen">
  <img src="screenshots/health.png" width="180" alt="Health screen">
  <img src="screenshots/journal.png" width="180" alt="Journal screen">
</p>

> Screenshots are placeholders until the corresponding image files are added. Use demo data or redact personal health and journal information before publishing.

## Features

- **Performance:** Browse HealthKit workouts and inspect custom time or distance intervals, including sport-specific pace and cadence analysis.
- **Sleep:** Explore sleep stages with a draggable timeline, snapping and haptic feedback; browse previous nights on a calendar and review stage totals.
- **Health:** View your most recent weigh-in regardless of the selected trend period, alongside nutrition and medication tracking.
- **Focus:** Pomodoro timer, daily tasks, and a persistent monthly calendar.
- **Journal:** Date-based entries, moods, and local photo/file attachments.

## Engineering highlights

- HealthKit authorization and historical sample retrieval, including overnight sleep windows and infrequent body-mass records.
- Workout interval analysis and activity-specific metrics.
- SwiftUI-driven date selection, interactive visualizations, and local journal persistence.
- Shared components and a dark, minimal design system.

## Tech stack

**Swift · SwiftUI · HealthKit · Xcode · Git/GitHub**

## Run locally

1. Clone the repository and open the `.xcodeproj` in Xcode.
2. Select an iOS device and configure your own signing team.
3. Enable required HealthKit entitlements and approve requested Health permissions.
4. Build and run. Some features require existing Apple Health records.

**Status:** Actively developed iOS prototype. Features and integrations are being tested and refined.
