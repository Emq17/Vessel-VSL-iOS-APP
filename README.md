# VSL — Vessel

**BUILT FOR PROGRESS.**  
**YOUR BODY. YOUR VESSEL.**

A native iOS app that brings training, health, sleep, focus, and journaling into one minimal workspace. Built with **SwiftUI** and **Apple HealthKit**, VSL turns personal data into actionable views without the clutter.

## App preview

<p align="center">
  <img src="screenshots/focus.png" width="185" alt="Focus timer and daily tasks" />
  <img src="screenshots/performance.png" width="185" alt="Performance workout analysis" />
  <img src="screenshots/health.png" width="185" alt="Health analytics and blood pressure" />
  <img src="screenshots/sleep.png" width="185" alt="Sleep stage timeline" />
  <img src="screenshots/journal.png" width="185" alt="Journal and mood tracking" />
</p>

## Features

- **Focus** — Pomodoro sessions, date-based task management, and an expandable calendar.
- **Performance** — Apple Health workout history with custom distance/time interval analysis and activity-specific metrics.
- **Health** — Latest weight and historical trends; latest logged nutrition, daily averages, and macro distribution; medication tracking; blood pressure and heart rate insights.
- **Sleep** — Apple Health sleep-stage breakdown, interactive timeline inspection, and historical calendar views.
- **Journal** — Dated entries, mood tracking, and attachments.

## Health analytics

- **Rolling date ranges:** 7D, 30D, and 90D mean consecutive calendar days ending today—not calendar months. Custom ranges are supported where available.
- **Blood pressure:** Systolic/diastolic trend chart, interactive point inspection with measurement timestamps, range averages, and calendar activity indicators.
- **Heart rate:** Latest measurements and range averages for heart rate, resting heart rate, HRV, VO₂ max, and cardio recovery.
- **Nutrition:** Latest logged day, daily-average calories and macronutrients across rolling or custom ranges, and a macro-energy donut chart wherever recorded data is available.
- **Weight:** Most recent recorded weigh-in remains visible independently of the selected historical trend range.

## Engineering

**Swift · SwiftUI · HealthKit · Swift Charts · Xcode · Git/GitHub**

- Native, reusable SwiftUI components with a consistent dark UI and lime accent.
- HealthKit permissions and sample retrieval for workouts, cardiovascular metrics, nutrition, weight, and sleep.
- Date-driven filtering, calendar indicators, and interactive data visualizations.
- Local persistence for productivity and journal workflows.

## Run locally

1. Clone this repository and open the Xcode project.
2. Configure your Apple development signing team and required HealthKit capabilities.
3. Run on a compatible iOS device and grant the requested Apple Health permissions.
4. Some dashboards require existing Apple Health data to populate.

## Status

**In active development.** VSL is a personal iOS project; features and HealthKit integrations are being refined and tested.

> **Privacy:** Screenshots are for demonstration. Health and journal information shown in public screenshots should be demo data or redacted.
