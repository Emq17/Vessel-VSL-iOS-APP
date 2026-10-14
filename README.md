# VSL — Vessel

**iOS fitness, health, and productivity app**

Built with Swift, SwiftUI, HealthKit, and Xcode. Includes activity-specific workout analytics, sleep insights, daily planning, and personal journaling.

## Overview

VSL is a personal iOS project that brings together workout performance, Apple Health data, sleep analysis, daily productivity, and personal journaling in a focused, minimal interface. Rather than treating every workout the same way, VSL adapts its analytics to the activity being viewed — from running cadence and custom intervals to swimming splits and time-based sessions.

The app is organized around five areas: **Focus → Performance → Health → Sleep → Journal**.

## App Preview

> **Screenshots coming soon.** Add real screenshots from the iPhone app here. Use sample data or crop/redact private health information before publishing.

<!-- Once you have screenshots, create a docs/screenshots/ folder and replace this placeholder:
| Focus | Performance | Health | Sleep | Journal |
|:--:|:--:|:--:|:--:|:--:|
| ![Focus](docs/screenshots/focus.png) | ![Performance](docs/screenshots/performance.png) | ![Health](docs/screenshots/health.png) | ![Sleep](docs/screenshots/sleep.png) | ![Journal](docs/screenshots/journal.png) |
-->

## Features

### Focus — Productivity without clutter
- Pomodoro-style focus and break timer
- Persistent to-do list with completion tracking
- Monthly calendar to review tasks by date

### Performance — Activity-aware workout analysis
- Read recent workouts from Apple Health / Apple Watch
- Select a recorded workout and view relevant metrics
- Running: cadence-oriented analysis and custom interval comparisons
- Swimming: swim-specific metrics and distance/interval tools
- Time-based workouts, such as jump rope: avoid irrelevant distance and pace fields
- Custom analysis options based on the selected workout type
- Analysis range and interval controls positioned above workout results for quick access

### Health — Daily metrics and longer-term trends
- Latest available Apple Health weigh-in, even when it was recorded before today
- Weight trend views with separate date-range filters (Latest, 7D, 30D, and other supported ranges)
- Nutrition data available through Apple Health
- Medication information and tracking views
- Today and historical summary periods

### Sleep — Explore nightly sleep history
- Last-night summary and historical sleep averages
- Monthly sleep calendar for selecting a wake-up date and reviewing the preceding night (draft integration; requires merging and on-device verification)
- Awake, REM, Core, and Deep sleep breakdowns when provided by Apple Health
- Interactive sleep-stage timeline placed directly beneath the date-range controls, with touch-and-drag selection, interval timestamps, and haptic feedback
- Full-width sleep metric rows with stage-matched color indicators; REM, Core, and Deep precede the Total Sleep summary
- Awake time shown separately because it does not contribute to Total Sleep

> Health and sleep metrics depend on what Apple Health and connected devices/apps actually record. Some calculations, particularly reconstruction of overnight sleep sessions, are still being validated against Apple Health.

### Journal — Daily reflection and mood tracking
- Calendar-based entries organized by date
- Mood selection and free-form daily writing
- Photo and file attachments saved in the app’s local Documents directory
- Edit, revisit, and delete entries; calendar indicators for days with content

> Journal is a new feature undergoing on-device testing. Entries and attachments are stored locally; there is no separate in-app encryption or passcode protection. Deleting the app may remove locally stored entries.

## Engineering Highlights

| Area | Implementation focus |
| --- | --- |
| **Native iOS UI** | SwiftUI views, reusable components, dark visual system, consistent accent color |
| **Health data** | HealthKit authorization, workout and wellness queries, date-window filtering |
| **Activity-specific logic** | Conditional metrics and custom analysis controls based on workout type |
| **Time-series analysis** | Workout intervals, cadence comparisons, and sleep-stage visualization |
| **Local state** | Persisted focus tasks, calendar dates, and timer settings |
| **Journal storage** | Date-indexed entries, mood data, and locally managed photo/file attachments |
| **Interaction design** | Touch-based sleep-stage selection and haptic feedback when moving between intervals |
| **Modular structure** | Separate views, models, data services, and shared UI components |

## Tech Stack

- **Language:** Swift
- **IDE:** Xcode
- **UI:** SwiftUI
- **Health integration:** Apple Health / HealthKit
- **Persistence:** Local device storage (including UserDefaults for focus state and app Documents storage for journal attachments)
- **Version control:** Git and GitHub

## Getting Started

### Requirements

- A Mac with Xcode
- A compatible iPhone and iOS SDK for the project's deployment target
- Apple Health data and permissions for health-related features
- Appropriate signing configuration for running on a physical device

### Run locally

1. Clone the repository:
   ```bash
   git clone https://github.com/Emq17/Vessel-VSL-iOS-APP.git
   ```
2. Open **`Untitled Project.xcodeproj`** in Xcode.
3. Select the main app target and configure your signing team and bundle identifier if needed.
4. Confirm the app's HealthKit capability and required privacy usage descriptions are configured.
5. Select your iPhone and build/run the app.
6. Grant the relevant Apple Health permissions when prompted.

> The Xcode project currently retains its original `Untitled Project` file and target naming. The product name is VSL; renaming project files is planned as a separate cleanup to avoid breaking project references.

## Privacy

VSL requests access to Apple Health data through iOS permission flows. Journal entries and attachments are stored locally on the device, without a separate VSL cloud account. Local storage is not the same as end-to-end encryption or an app-specific lock. Do not commit personal health exports, private journal entries, unredacted screenshots, secrets, or provisioning credentials to this repository.

## Recent Improvements

- Moved workout analysis range controls above results on distance-based activities.
- Updated weight retrieval to show the most recent recorded weigh-in rather than requiring a measurement today; renamed the weight selector to **Latest**.
- Moved the interactive sleep-stage timeline above the metric rows, retaining stage selection and haptic feedback.
- Replaced the sleep metric grid with full-width, color-coded rows and moved Total Sleep beneath the sleep stages.
- Prepared a date-selectable monthly sleep calendar so a selected day corresponds to the sleep session ending that morning; integration into the latest project files is pending.

## Project Status

**Actively developed.** Core app screens and analysis workflows are implemented, with a newly added Journal feature and ongoing refinement of sleep-session calculations, streamlined sleep metric presentation, accessible workout interval controls, latest-weigh-in handling, and device testing. The sleep calendar is currently a draft update and has not been merged into the latest project snapshot or verified in Xcode. This repository is a portfolio project, not a medical product or clinically validated health tool.

## Roadmap

- [ ] Merge the monthly sleep calendar into the latest app source and verify date-to-night matching on device

- [ ] Validate sleep totals and stage boundaries against Apple Health across different nights
- [ ] Test Journal entry persistence, attachments, and deletion on a physical iPhone
- [ ] Evaluate optional app-lock and export/backup features for journal data
- [ ] Expand automated tests for interval and date-boundary calculations
- [ ] Add privacy-safe screenshots and a short app demo
- [ ] Refine accessibility, dynamic type, and device-size layouts
- [ ] Clean up the Xcode project and target naming

**Built with Swift, SwiftUI, HealthKit, and Xcode.**
