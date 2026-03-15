# Beta Sprayer — Claude Code Handoff

## Project Overview
**App name:** Beta Sprayer  
**Developer:** Noa CHallis (@noachallis) — complete iOS beginner  
**GitHub repo:** https://github.com/noachallis/beta-sprayer  
**Platform:** iOS (SwiftUI)  
**Goal:** Take a photo of an indoor boulder problem → find Instagram beta videos for it

---

## What's Been Done So Far

### 1. GitHub Repo
- Repo created at https://github.com/noachallis/beta-sprayer
- Has a README.md and Swift .gitignore

### 2. Xcode Project
- Developer has created an Xcode project called `BetaSprayer` (SwiftUI, Swift)
- The default Xcode files exist: `BetaSprayerApp.swift`, `ContentView.swift`, `Assets.xcassets`, `Preview Content`

### 3. Source Files to Add/Replace
The following Swift files have been written and need to be placed in the Xcode project.
The developer may or may not have done this yet — check what exists and fill in the gaps.

#### Replace (Xcode generated placeholders):
- `BetaSprayer/BetaSprayerApp.swift` — app entry point with `@main`
- `BetaSprayer/Views/ContentView.swift` — home screen with camera + PhotosPicker + navigation to results

#### Create (new files, add to Xcode project):
- `BetaSprayer/Views/CameraView.swift` — UIViewControllerRepresentable wrapping UIImagePickerController
- `BetaSprayer/Views/ResultsView.swift` — shows Instagram hashtag buttons and deep link to Instagram
- `BetaSprayer/ViewModels/SearchViewModel.swift` — @MainActor ObservableObject, handles image state + Instagram URL logic

#### Permissions (Info.plist):
```xml
<key>NSCameraUsageDescription</key>
<string>Beta Sprayer uses your camera to take photos of boulder problems so you can find beta videos for them.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Beta Sprayer accesses your photo library so you can choose a photo of a boulder problem.</string>
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>instagram</string>
</array>
```

---

## Architecture
- **Pattern:** MVVM
- **UI:** SwiftUI throughout, with UIKit bridge for camera only
- **Min target:** iOS 17+
- **No external dependencies** (no CocoaPods, no SPM packages yet)

## Folder Structure (target state)
```
BetaSprayer/
├── BetaSprayerApp.swift
├── Info.plist
├── Assets.xcassets
├── Preview Content/
├── Views/
│   ├── ContentView.swift
│   ├── CameraView.swift
│   └── ResultsView.swift
└── ViewModels/
    └── SearchViewModel.swift
```

---

## Current Status & Next Steps

### Immediate tasks
1. Verify all Swift files are in place and the project builds (`Cmd+B` in Xcode)
2. Fix any build errors (likely missing group folders or file targets)
3. Run on a real iPhone (camera requires physical device, not Simulator)

### Roadmap (future sessions)
- [ ] Use Apple Vision framework to detect hold colours from the photo
- [ ] Build smarter Instagram search queries based on hold colour + grade
- [ ] Add gym detection via CoreLocation
- [ ] Save favourite beta videos
- [ ] Share problems with climbing friends

---

## Developer Notes
- Noac is a **complete iOS beginner** — explain things clearly, avoid jargon
- Prefer **SwiftUI** over UIKit wherever possible
- Ask before adding any third-party dependencies
- Camera functionality **cannot be tested in Simulator** — needs a real iPhone
- Node.js was upgraded to fix a Claude Code startup error (`TypeError: Object not disposable` — caused by Node v20.3.0 being too old)

---

## How to Help
When the developer runs `claude` in the `beta-sprayer` directory, you should:
1. Check what Swift files currently exist
2. Create or fix any missing/incomplete files
3. Verify the project structure matches the target above
4. Help them get to a clean build (`Cmd+B` with no errors)
