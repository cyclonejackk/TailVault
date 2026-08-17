---
type: guide
name: App Store Submission Guide — TailVault
created: 2026-07-10
updated: 2026-07-10
status: reference
tags: [tailvault, ios, app-store, guide]
---

# Getting TailVault onto your iPhone (and the App Store)

Three paths, cheapest first. For personal use, **Path 2 (TestFlight) is the sweet spot** — full App Store review is only worth it if you want strangers to download it. TailVault's universal-species design makes it a legitimate App Store candidate if you go that far.

## Path 1 — Free: install directly from Xcode ($0)

1. Sign into Xcode with your Apple ID (Xcode → Settings → Accounts).
2. Plug in your iPhone, select it as the run target, press ⌘R.
3. On the phone: Settings → General → VPN & Device Management → trust your developer certificate.

**Catch:** the app expires every **7 days** and needs re-installing from Xcode. Fine for testing, annoying for daily use.

## Path 2 — TestFlight ($99/year, no review hassle)

Requires the Apple Developer Program but skips full App Store review (TestFlight builds get a lighter "beta review," usually approved within a day).

1. Enroll at [developer.apple.com/programs](https://developer.apple.com/programs/) — $99/year, individual is fine.
2. In Xcode: Signing & Capabilities → select your paid team. Set a unique bundle ID like `com.nateohrt.tailvault`.
3. **Product → Archive**, then in the Organizer window click **Distribute App → TestFlight & App Store → Upload**.
4. In [App Store Connect](https://appstoreconnect.apple.com) → your app → TestFlight tab → add yourself as an internal tester.
5. Install the **TestFlight app** on your iPhone, accept the invite, install TailVault.

**Result:** app lasts **90 days** per build, up to 100 internal testers (family and pet sitters count), re-upload takes 10 minutes when a build expires. This is how most personal apps live.

## Path 3 — Full App Store release ($99/year + review)

Everything in Path 2, plus:

### 1. Create the app record
App Store Connect → My Apps → **+ New App**. Pick the bundle ID, name — check that "TailVault" is free in App Store Connect when you create the record (name collisions are common; a backup like "TailVault Pet Tracker" works), primary language, SKU (any string).

### 2. Required metadata
- **Description** (pet profiles, med logs you can send your vet, attendance, sitter sharing), **keywords** (pet, tracker, medication, vet, dog, cat, reminder…), **support URL** (a simple page or GitHub README), **marketing URL** (optional).
- **Category:** Lifestyle or Utilities.
- **Age rating questionnaire:** all "None" → 4+.

### 3. Screenshots
Required sizes (as of 2026): **6.9" iPhone** (1320 × 2868) and **6.5" iPhone** (1284 × 2778 or 1242 × 2688). Take them in the Xcode Simulator (⌘S saves a correctly-sized PNG). 3–5 screenshots: pet list, a profile, med log, attendance, dark mode. The concept mockups in `Concept Mockups/` show the framing to aim for.

### 4. App icon
1024 × 1024 PNG, no transparency, no rounded corners (Apple rounds it). Add it to `Assets.xcassets → AppIcon` in Xcode. On brand: a paw print over a vault/shield shape, or a curled tail forming a keyhole.

### 5. Privacy
- **Privacy policy URL** — required even with zero data collection. One paragraph ("TailVault stores all data on-device; nothing is collected or transmitted") hosted anywhere public.
- **App Privacy questionnaire** in App Store Connect: answer **"Data Not Collected"** — true for this app, everything is on-device SwiftData with no analytics, no network calls.

### 6. Submit
- Upload a build (same Archive flow as TestFlight).
- Attach the build to version 1.0, fill in "What's New," pick pricing (**Free**), and click **Submit for Review**.
- No demo account needed (no login). In Review Notes, one line: "All data is stored locally on device. Seed data loads on first launch so the reviewer sees a populated app."

### 7. Review expectations
- Typical wait: **24–48 hours**.
- Most likely rejection risks for an app like this and how they're already handled:
  - *2.1 App Completeness* — crashes: test on a real device first.
  - *4.2 Minimum Functionality* — "just a database" rejections happen to trivial apps; TailVault's reminders, dose logging, vet reports, sharing, CSV export, and attendance system comfortably clear the bar.
  - *5.1.1 Privacy* — no permission over-asking: it only requests notifications (with purpose) and photo picking (which needs no permission).
- If rejected, you reply or fix and resubmit in the Resolution Center; second reviews are usually faster.

## Checklist (App Store path)

- [ ] Apple Developer Program enrolled ($99/yr)
- [ ] Bundle ID set (`com.nateohrt.tailvault`), app builds and runs on a physical iPhone
- [ ] App icon 1024×1024 added
- [ ] App record created in App Store Connect ("TailVault" name availability checked)
- [ ] Screenshots for both required sizes
- [ ] Privacy policy URL live
- [ ] Privacy questionnaire: Data Not Collected
- [ ] Age rating: 4+
- [ ] Build archived and uploaded from Xcode
- [ ] Submitted for review

## Practical recommendation

Do Path 1 today to get it on your phone, enroll in the Developer Program this week, then live on TestFlight (Path 2). Only file for full App Store review if you want it public — at which point the seed data should be swapped for an empty-state onboarding screen, since shipping your cats' microchip numbers to the public is not ideal.
