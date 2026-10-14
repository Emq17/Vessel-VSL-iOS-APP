# VSL — Vessel

**Native iOS health, fitness, and productivity app**

Built with **Swift, SwiftUI, and HealthKit**, VSL brings workout interval analysis, sleep-stage exploration, health tracking, focused planning, and journaling into one minimalist interface.

## Features

- **Performance:** Browse HealthKit workouts and inspect custom time or distance intervals, including sport-specific pace and cadence analysis.
- **Sleep:** Explore sleep stages with a draggable timeline, snapping and haptic feedback; browse previous nights on a calendar and review stage totals.
- **Health:** View your most recent weigh-in regardless of the selected trend period, alongside nutrition and medication tracking. Blood pressure and cardiovascular metrics are planned HealthKit integrations.
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

**Status:** Actively developed iOS prototype. Blood pressure, heart rate, resting heart rate, HRV, VO₂ max, and cardio recovery integration are planned, not yet implemented.
