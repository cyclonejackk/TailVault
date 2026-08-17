---
type: project
name: TailVault — Pet Tracker iPhone App
status: source-complete
created: 2026-07-10
updated: 2026-07-10
platform: iOS 17+
stack: [Swift, SwiftUI, SwiftData]
tags: [tailvault, ios, project]
---

# TailVault — every pet, one vault

iPhone app for tracking a household of pets — any species. The pitch: **Notion for pets** — structured profiles for the stuff every pet has (meds, vet visits, weights), plus custom fields for everything else.

## What it does

| Area | Features |
|------|----------|
| **Any species** | Preset species picker (cat, dog, bird, rabbit, reptile, fish, horse, goat, chicken…) or type a custom one; species emoji throughout the UI |
| **Profiles** | Photo, DOB/gotcha day, sex, breed, markings, microchip, rabies tag, indoor/outdoor, weight log, vaccine due dates |
| **Custom fields** | Add any field to any pet — insurance policy #, groomer, harness size, tank temperature. The "Notion for pets" part |
| **Health** | Active conditions, allergies, health notes |
| **Medications** | Flexible frequencies: once/twice/3× daily, every other day, **every N days**, weekly, monthly, as-needed; multiple dose times; local notification reminders (interval schedules are batch-scheduled and topped up at launch) |
| **Med dose log** | One-tap "Given ✓" (swipe on profile, button on Schedule tab), backdated doses, skipped doses with notes — then **send the administration record to your vet** as text or CSV |
| **Vet** | Clinic directory (tap-to-call), visit history with outcome notes, upcoming appointments with day-before reminders |
| **Personality** | Hiding spots, favorite toys, food, treats, likes-treats/likes-pets scale, temperament and sitter notes |
| **Family** | Parent/offspring links (bidirectional) and sibling links; tap through profiles |
| **Sitter sharing** | One tap shares a formatted handoff for one pet or the whole household via Messages/Mail/AirDrop |
| **Attendance** | Checklist with each pet's photo, date/time, location ("House", "Barn"…) with recent-location chips, all-present shortcut, saved history |
| **Export** | Pets → CSV, Medication log → CSV, Attendance → CSV; opens directly in Numbers/Excel/Google Sheets |
| **Schedule tab** | Everything upcoming across all pets: meds (with "Given ✓" logging), vet visits, vaccines due in 60 days |
| **Themes** | System / Light / Dark toggle in Settings |

Ships pre-seeded with all 8 cats (Atwood, Callen, Dice, Fergus, Gothi, Hermione, Midas, Watson) from this vault's Cat Health profiles. Seeding only runs on first launch — everything is editable in-app afterward.

## File map

```
TailVault/
├── TailVaultApp.swift           App entry, theme, SwiftData container,
│                                reminder top-up at launch
├── Models/
│   ├── Models.swift             Pet, SpeciesCatalog, CustomField, WeightEntry,
│   │                            Vaccination, Medication, MedDoseLog, VetClinic,
│   │                            VetVisit, AttendanceRecord/Entry
│   └── SampleData.swift         First-launch seed (your 8 cats)
├── Services/
│   ├── CSVExporter.swift        Pets + med log + attendance spreadsheets
│   ├── SitterSummary.swift      Sitter handoff text + VetReport (med history)
│   └── NotificationManager.swift Flexible med reminders + visit reminders
└── Views/
    ├── ContentView.swift        4-tab shell
    ├── PetListView.swift        Home list, search, export, share
    ├── PetDetailView.swift      Full profile with dose-log swipe action
    ├── PetEditView.swift        Add/edit pet, species picker, custom fields,
    │                            photo picker, family links
    ├── MedicationEditView.swift Med editor: frequencies, dose times, reminders
    ├── MedLogView.swift         Dose logging + history + send-to-vet
    ├── VetVisitEditView.swift   Visit/appointment editor
    ├── AttendanceView.swift     Attendance taker + history
    ├── ScheduleView.swift       Cross-pet upcoming view with "Given ✓"
    ├── SettingsView.swift       Theme, exports, clinic manager
    └── Components.swift         Avatar, pickers, shared rows
```

## Building it (requires a Mac with Xcode 15+)

1. Open Xcode → **File → New → Project → iOS → App**.
2. Product Name: `TailVault`. Interface: **SwiftUI**. Storage: **None** (we use SwiftData directly). Language: **Swift**. Minimum deployment: **iOS 17.0**.
3. Delete the generated `ContentView.swift` and `TailVaultApp.swift`.
4. Drag the `TailVault/` folder contents (all `.swift` files, keeping the folder groups) into the project navigator. Check "Copy items if needed."
5. In the target's **Signing & Capabilities**, pick your Apple ID team.
6. **App icon:** open `Assets.xcassets` → **AppIcon** and drag `AppIcon/AppIcon-1024.png` into the 1024×1024 "App Store" slot (Xcode 15+ generates every other size from it).
7. Plug in your iPhone (or pick a simulator) and press **Run** (⌘R).

No Info.plist keys are strictly required: the photo picker (`PhotosPicker`) and local notifications use system prompts that don't need usage-description strings.

Free Apple ID signing works for personal use but the install expires after 7 days. See [[App Store Submission Guide]] for TestFlight and App Store options that don't expire.

## Data safety & iCloud sync

Data is stored on-device (SwiftData/SQLite). What that means today:

| Scenario | Data survives? |
|----------|----------------|
| App update / re-run from Xcode | ✅ Yes |
| New phone restored from full iCloud/Finder backup | ✅ Yes |
| Delete app, reinstall | ❌ No — gone |
| New phone set up as new (no backup restore) | ❌ No |

**The models are already CloudKit-compatible** (no unique constraints, defaults everywhere, optional relationships), so turning on real iCloud sync — which survives delete/reinstall and syncs across devices — requires **zero code changes**, just entitlements:

1. Requires the paid Apple Developer Program ($99/yr) — free accounts can't use iCloud entitlements.
2. Xcode → target → **Signing & Capabilities** → **+ Capability** → **iCloud** → check **CloudKit** → "+" a container named `iCloud.<your-bundle-id>`.
3. **+ Capability** → **Background Modes** → check **Remote notifications**.
4. Run. SwiftData detects the entitlement and syncs automatically.

Caveats: turn it on *before* you need it (it can't resurrect data that's already deleted); sync needs the user signed into iCloud; and if a second device has already seeded the 8 sample pets, you may see duplicates after first sync — delete one set.

Until then, the CSV exports (Settings → Export) are your manual backup — email yourself one occasionally.

## Roadmap

### ✅ Built (no paid account needed)
- Home dashboard: a "Today" progress strip (Meds / Meals / Walks) over tick-off rows for today's doses, meals, and scheduled walks — plus needs-attention alerts and upcoming visits. Doses show their dosage next to the name, so the same drug at two strengths in one day never blurs together. Swipe right on any row to undo a mis-tap.
- Walk routines: recurring walks, potty breaks, and enrichment per pet (times, duration, days of week), checked off from the dashboard into the activity log
- Weight trend charts (Swift Charts)
- PDF exports: vet med report, sitter profile, household guide
- Document locker: photo docs per pet (vaccine certs, insurance cards)
- Expense tracking per pet with categories, year total, CSV export
- Symptom/observation journal with photos
- Lost-pet flyer generator (owner contact set in Settings)
- "Remembered 🌈" section for inactive pets
- Confirm-before-delete for pets

### 🔒 Needs the $99/yr Apple Developer Program
1. **iCloud sync (CloudKit)** — survives delete/reinstall + new phones. Models are ready; it's entitlement-only. Do this first.
2. **TestFlight** — no more 7-day expiry; invite family and sitters.
3. **Family sharing** — CloudKit shared database so two people log doses without double-dosing. Needs #1 plus real work (CKShare).
4. **Sitter share (native)** — share one household to a sitter's iCloud account; they need the app via TestFlight.

### 🌐 Needs a small web backend (free tiers exist; real work)
- **Sitter web link** — sitter opens a URL in a browser, no app; checkmarks flow back live.

### 🧰 Needs Xcode project surgery (free, but fiddly setup)
- **Home Screen widget** — today's meds at a glance. Requires a Widget Extension target + App Group; revisit alongside the paid-account work.

### 💡 Someday
- Supply/food reorder reminders ("bag lasts ~40 days")
- Attendance streaks / "last seen" per pet
- Photo gallery per pet
- Custom field templates per species (tank specs, farrier schedule)
- Breeder mode: litters and pedigree trees from the family links
