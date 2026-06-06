# ChoreQuest 🏆

A private, offline iPhone app that turns home chores into a game. Earn points for every chore you
finish, see who's winning, and keep a timestamped history — all stored **on your phone**, nothing
online.

- **Native SwiftUI**, iOS 17+
- **SwiftData** local persistence — data lives on the device and survives app updates & re-signing
- **Zero third-party dependencies**
- **Not published anywhere** — you build it onto your own iPhone from Xcode

---

## Requirements

- A Mac with **Xcode 16 or newer** (free from the Mac App Store). The committed project file uses the
  Xcode 16 format.
- An **Apple ID** (a free one is fine — see *Signing* below).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — only needed if you change the project structure
  and want to regenerate the Xcode project: `brew install xcodegen`.

## Build & run on your iPhone

1. **Open the project**
   ```bash
   open ChoreQuest.xcodeproj
   ```
   (The `.xcodeproj` is committed, so you don't need XcodeGen just to build.)

2. **Set your signing team** — select the **ChoreQuest** target → **Signing & Capabilities** →
   tick *Automatically manage signing* → choose your Apple ID under **Team**. Add your Apple ID in
   Xcode → Settings → Accounts if it isn't there yet.

3. **Plug in your iPhone** (or use wireless debugging), select it as the run destination, and press
   **⌘R**. The first time, trust the developer certificate on the phone:
   **Settings → General → VPN & Device Management → (your Apple ID) → Trust**.

### Free Apple ID note
With a free account the app's provisioning expires after **7 days** — just re-run from Xcode to
reinstall it. **Your saved data is preserved** across re-signs and app updates; it's only lost if you
*delete* the app. (A paid Apple Developer Program account, $99/yr, extends this to a year — no code
changes needed.) You can also use the in-app **Export backup** as extra insurance (CQ-5).

## Regenerating the Xcode project

The source of truth for the project is [`project.yml`](project.yml) (XcodeGen). If you add/rename
folders and want a clean project file:
```bash
xcodegen generate
```

## Project layout

```
project.yml                  XcodeGen spec (source of truth)
ChoreQuest.xcodeproj/        Generated Xcode project (committed for convenience)
ChoreQuest/
  ChoreQuestApp.swift        App entry point
  Views/                     SwiftUI screens
    Components/              Reusable views
  Resources/                 Assets.xcassets (app icon, accent color)
  Models/                    SwiftData @Models           (added in CQ-2)
  Helpers/                   Small utilities             (added in CQ-2+)
Tests/                       Pure-logic unit tests        (added in CQ-5)
```

## Roadmap (tracked as issues / PRs)

- **CQ-1** Project scaffold (this PR) — buildable empty shell
- **CQ-2** Data layer + Manage screen (people & chores)
- **CQ-3** Quick Log fast-add flow
- **CQ-4** Leaderboard + History
- **CQ-5** Polish, stats, backup, tests
