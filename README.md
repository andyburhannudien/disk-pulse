# DiskPulse

**NVMe SSD health and S.M.A.R.T. monitoring for macOS.**

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-FA7343.svg?style=flat&logo=swift)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2012%2B-000000.svg?style=flat&logo=apple)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

DiskPulse reads the NVMe S.M.A.R.T. data that macOS already exposes through `diskutil`, without kernel extensions, root privileges, or third-party services. It ships as a native menu bar application, a scriptable command-line tool, and a reusable Swift library.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Notifications](#notifications)
- [How It Works](#how-it-works)
- [Health Grading](#health-grading)
- [JSON Output](#json-output)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Limitations](#limitations)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

| Surface | Description |
|---|---|
| **DiskPulse.app** | Menu bar application with a popover summary and a full dashboard window. |
| **`diskpulse`** | ANSI terminal dashboard and JSON output for scripting. Bundled inside the app. |
| **DiskPulseCore** | Foundation-only Swift library for scanning disks and parsing NVMe metrics. |

### What it reports

- Health percentage and NAND wear (`PERCENTAGE_USED`)
- Available spare blocks and the vendor's warning threshold
- Terabytes Written (TBW) and Terabytes Read (TBR), including the 128-bit counter
- Composite NVMe temperature in Celsius and Fahrenheit
- Power-on hours, power cycles, and unsafe shutdowns
- Media errors, error-log entries, and host I/O command counts
- Average daily write rate derived from TBW and power-on hours

### Data source and safety

DiskPulse runs entirely in user space. It invokes `/usr/sbin/diskutil` and parses the resulting property lists:

- `diskutil list -plist` — enumerate whole disks
- `diskutil info -plist <id>` — read media properties and `SMARTDeviceSpecificKeysMayVaryNotGuaranteed`

There are no kernel extensions, no privileged helpers, no background network requests, and no telemetry. The only outbound action is opening the GitHub repository in your browser when you click the GitHub icon.

---

## Features

### Menu bar application

- Configurable menu bar label: icon only, health percentage, temperature, or both.
- Warning icon when the drive reaches `WARNING` or `CRITICAL`.
- Popover dashboard with health gauge, wear, spare reserve, TBW/TBR, daily writes, power-on hours, media errors, and a 24-hour temperature chart.
- Full dashboard window with a multi-disk sidebar and detailed health, thermal, endurance, and integrity sections.
- Diagnostic summary with actionable advice.
- Raw S.M.A.R.T. JSON with copy and export actions.
- Clickable GitHub link with a repository tooltip in the popover and dashboard header.
- Native notifications with per-rule cooldowns.
- Launch at login via a user LaunchAgent.
- Per-disk history persisted across launches.
- No Dock icon (`LSUIElement`), no menu bar clutter beyond a single item.

### Command-line interface

- Visual ANSI dashboard with health bar, thermal status, and recommendations.
- Structured JSON output (`--json`) suitable for scripts and monitoring exporters.
- Targeted scans (`--disk`) and physical-disk scans (`--all`).
- Same parsing engine as the app.

---

## Requirements

- **macOS 12.0 Monterey or later**
- **Swift 5.9+** with Xcode Command Line Tools (`xcode-select --install`)
- No third-party Swift packages

The app intentionally avoids macOS 13+ APIs so that it remains compatible with Monterey. Local verification was performed on macOS 26.5 (Intel); the deployment target is macOS 12.

---

## Installation

### From a release DMG

Download the artifact that matches your Mac:

| Architecture | File |
|---|---|
| Apple Silicon | `DiskPulse-<version>-macos-arm64.dmg` |
| Intel | `DiskPulse-<version>-macos-x86_64.dmg` |
| Universal | `DiskPulse-<version>-macos-universal.dmg` |

Verify the download, open the image, and drag DiskPulse to Applications:

```bash
shasum -a 256 -c DiskPulse-<version>-macos-<arch>.dmg.sha256
open DiskPulse-<version>-macos-<arch>.dmg
```

The disk image contains `DiskPulse.app` and an `Applications` shortcut. The CLI is bundled at `DiskPulse.app/Contents/Resources/diskpulse`.

### Build from source

```bash
git clone https://github.com/andyburhannudien/disk-pulse.git
cd disk-pulse

# Build dist/DiskPulse.app (release configuration, ad-hoc signed)
make app

# Launch it
make run
```

`make app` produces a self-contained bundle:

```
dist/DiskPulse.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/DiskPulseApp
    └── Resources/
        ├── AppIcon.icns
        └── diskpulse          # bundled CLI
```

To produce a distributable disk image from the local build:

```bash
make dmg
```

### Install from a local build

Build first, then install:

```bash
make app
sudo make install
```

This installs:

- `/Applications/DiskPulse.app`
- `/usr/local/bin/diskpulse`

`make install` uses the already-built `dist/DiskPulse.app` and its bundled CLI; it does not rebuild the project as root. You can also copy the app manually:

```bash
ditto dist/DiskPulse.app /Applications/DiskPulse.app
open /Applications/DiskPulse.app
```

Move the app to `/Applications` before enabling **Launch at login**; the login item stores the bundle path.

### Uninstall

1. Open **Settings** and disable **Launch at login**, then quit DiskPulse from the menu bar.
2. Remove the application and CLI:

   ```bash
   rm -rf /Applications/DiskPulse.app
   rm -f /usr/local/bin/diskpulse
   ```

3. Remove the LaunchAgent, history, and preferences:

   ```bash
   launchctl bootout "gui/$(id -u)/dev.diskpulse.app" 2>/dev/null || true
   rm -f "$HOME/Library/LaunchAgents/dev.diskpulse.app.plist"
   rm -rf "$HOME/Library/Application Support/DiskPulse"
   defaults delete dev.diskpulse.app
   ```

### Code signing

Local builds are ad-hoc signed, which is sufficient for local development and normally allows notifications to work:

```bash
make app
```

To sign with a Developer ID certificate:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make app
```

The build script enables the hardened runtime and a secure timestamp when a non-ad-hoc identity is provided. Notarization is not automated yet; distributed builds may trigger Gatekeeper on other Macs until they are notarized.

### Regenerating the icon

```bash
make icon
```

`scripts/make-icon.swift` renders the icon with AppKit and converts the iconset with `iconutil`. The generated `Resources/AppIcon.icns` is committed, so this step is only needed when changing the artwork.

---

## Usage

### Menu bar application

- **Left-click** the drive icon to open the popover.
- **Right-click** for a quick menu: Refresh Now, Open Dashboard, Settings, Quit.
- Use the GitHub icon in the popover or dashboard header to open this repository.
- The dashboard lists every physical disk; synthesized APFS containers are filtered out automatically.

Optional launch arguments:

```bash
# Open directly to the dashboard
open -a DiskPulse --args --dashboard

# Open directly to settings
open -a DiskPulse --args --settings
```

### Command-line interface

```text
Usage:
  diskpulse [options]

Options:
  --disk <id>       Target a specific disk identifier (for example disk0)
  --json            Output an array of reports as JSON
  --all             Scan every physical whole disk
  -h, --help        Show help
  -v, --version     Show the version
```

Without arguments, DiskPulse scans `disk0`, the primary physical disk on most Macs. Always target the whole disk rather than a partition when you need NVMe S.M.A.R.T. metrics:

```bash
diskpulse --disk disk0
```

Example terminal output:

```text
╔══════════════════════════════════════════════════════════════════════════════════╗
║                     DISKPULSE - macOS SSD HEALTH MONITOR                         ║
╚══════════════════════════════════════════════════════════════════════════════════╝

  Drive Model:         PM991a NVMe Samsung 512GB
  Device Node:         disk0 (/dev/disk0)
  Protocol / Bus:      Solid State Drive (SSD) via PCI-Express (Internal)
  Total Capacity:      512.1 GB (512,110,190,592 bytes)
  SMART Driver Status: ● VERIFIED

  ─── OVERALL HEALTH ASSESSMENT ──────────────────────────────────────────────────
  Health Score:      [███████████████████████████░] 95%  Status:  EXCELLENT
  Wear Level:        5% used
  Spare Reserve:     99% (Threshold: 50%)

  ─── THERMAL & OPERATIONAL CONDITIONS ───────────────────────────────────────────
  Current Temp:      37.9°C / 100.1°F [Cool]
  Power On Hours:    3,286 hours (~136.9 days active)
  Power Cycles:      1,378 reboots/starts
  Unsafe Shutdowns:  88

  ─── ENDURANCE & WORKLOAD (TBW) ────────────────────────────────────────────────
  Total Written:     34.57 TB (67,528,787 NVMe Data Units)
  Total Read:        60.04 TB (117,264,542 NVMe Data Units)
  Avg Daily Writes:  258.58 GB/day

  ─── INTEGRITY & RELIABILITY ───────────────────────────────────────────────────
  Media Errors:      0 (No bad sectors/errors)
  Error Log Entries: 0
```

The CLI is also available inside the app bundle:

```bash
/Applications/DiskPulse.app/Contents/Resources/diskpulse --json
```

---

## Configuration

Settings are stored in the standard UserDefaults domain `dev.diskpulse.app`. In-app changes take effect immediately; external `defaults write` changes require relaunching the app.

| Key | Default | Description |
|---|---|---|
| `refreshInterval` | `60` | Automatic scan interval in seconds. Supported values: 15, 30, 60, 300, and 0 (manual). |
| `menuBarDisplay` | `healthAndTemperature` | `iconOnly`, `health`, `temperature`, or `healthAndTemperature`. |
| `notificationsEnabled` | `false` | Enables native notifications after user authorization. |
| `temperatureThreshold` | `65` | Thermal alert threshold in Celsius (50–90). |
| `notifyHealthDrop` | `true` | Alert when health falls 5 or more points from the stored baseline. |
| `notifyMediaErrors` | `true` | Alert when the media error count increases. |
| `launchAtLogin` | `false` | Launch-at-login preference. The Settings toggle also verifies the LaunchAgent and prompts if unavailable. |
| `preferredDiskID` | none | Disk selected in the dashboard; `Automatic` when unset. |
| `keepHistory` | `true` | Persists temperature/health samples to disk. |

Notification bookkeeping is stored under `lastNotified.*` and `healthBaseline.*`; these keys are managed automatically.

---

## Notifications

Notifications are optional and require running from `DiskPulse.app` (the raw executable disables them safely). Authorization is requested when you enable notifications, not at launch.

| Alert | Trigger | Cooldown |
|---|---|---|
| Thermal | Temperature ≥ threshold (default 65°C) | 30 minutes per disk |
| Spare blocks | `availableSpare < availableSpareThreshold` | 24 hours per disk |
| Media errors | Media error count increases between scans | 6 hours per disk |
| Health drop | Health falls ≥ 5 points from baseline | 24 hours per disk |
| Grade drop | Health grade worsens between scans | 24 hours per disk |

The first successful scan establishes the baseline and does not emit alerts. Cooldowns are persisted in UserDefaults, so restarting the app does not bypass them.

---

## How It Works

### Scan pipeline

1. `diskutil list -plist` returns the list of whole disks.
2. Each identifier is inspected with `diskutil info -plist`.
3. Disks with `VirtualOrPhysical == "Virtual"` (APFS synthesized containers) are skipped.
4. The `SMARTDeviceSpecificKeysMayVaryNotGuaranteed` dictionary is parsed into `NVMeSMARTMetrics`.
5. Scans run on a serial background queue; published state is updated on the main thread.
6. The app records a history sample at most once per minute and notifies observers.

### TBW/TBR math

NVMe reports data units rather than bytes. One data unit is defined as:

```
1 data unit = 1000 × 512 bytes = 512,000 bytes
```

The 128-bit counter is split across `DATA_UNITS_WRITTEN_0` (low word) and `DATA_UNITS_WRITTEN_1` (high word). DiskPulse combines them without integer overflow:

```
totalUnits = high × 2^64 + low
TBW        = totalUnits × 512,000 / 10^12
```

`dataUnitsWrittenRaw` / `dataUnitsReadRaw` expose the low 64-bit word for compatibility. `dataUnitsWrittenTotal` / `dataUnitsReadTotal` expose the full counter as a `Double`.

### Architecture

```
┌─────────────────────────────────────────────────────┐
│ DiskPulseApp (macOS 12+)                            │
│ AppKit lifecycle + SwiftUI                          │
│ NSStatusItem · NSPopover · NSWindow                 │
└───────────────────────┬─────────────────────────────┘
                        │
                  DiskPulseCore
        ┌───────────────┴────────────────┐
        │ DiskPulseScanner               │
        │ DiskReport · NVMeSMARTMetrics  │
        └───────────────┬────────────────┘
                        │ /usr/sbin/diskutil
                        ▼
               NVMe S.M.A.R.T. data
```

`DiskPulseCLI` links the same core and renders either an ANSI dashboard or JSON.

### Project layout

```
Package.swift
Sources/
├── DiskPulseCore/          # Scanner, models, parsing
├── DiskPulseCLI/           # Terminal UI and argument handling
└── DiskPulseApp/
    ├── main.swift          # NSApplication entry point
    ├── App/                # AppDelegate and environment wiring
    ├── Models/             # Settings, scan store, history
    ├── Services/           # Notifications, login item, exporting
    ├── Views/              # Popover, dashboard, settings, components
    └── Utilities/          # Formatting and color helpers
Tests/
└── DiskPulseCoreTests/     # Dependency-free self-test harness
Resources/
├── Info.plist
└── AppIcon.icns
scripts/
├── build-app.sh
├── make-dmg.sh
└── make-icon.swift
```

### macOS 12 compatibility

The app deliberately avoids newer APIs:

| Avoided (macOS 13+) | Replacement |
|---|---|
| `MenuBarExtra` | `NSStatusItem` + `NSPopover` |
| `Window` / `Settings` scenes | `NSWindow` + `NSHostingView` |
| `NavigationSplitView` | `HSplitView` |
| Swift Charts | Custom `Path` line/area chart |
| `SMAppService` | User LaunchAgent |
| `@Observable` | `ObservableObject` + `@Published` |

---

## Health Grading

Grades are evaluated top to bottom; the first matching condition wins.

| Grade | Condition |
|---|---|
| **CRITICAL** | Media errors > 0, or available spare below the vendor threshold |
| **WARNING** | Available spare below 80%, or wear ≥ 90% |
| **FAIR** | Wear between 70% and 89% |
| **GOOD** | Wear between 20% and 69% |
| **EXCELLENT** | Wear below 20% |

---

## JSON Output

`diskpulse --json` always emits an array, even for a single disk. Example:

```json
[
  {
    "deviceIdentifier": "disk0",
    "deviceNode": "/dev/disk0",
    "mediaName": "PM991a NVMe Samsung 512GB",
    "protocolType": "PCI-Express",
    "isSolidState": true,
    "isInternal": true,
    "totalSizeBytes": 512110190592,
    "totalSizeFormatted": "512.1 GB",
    "smartStatus": "Verified",
    "nvmeMetrics": {
      "availableSpare": 99,
      "availableSpareThreshold": 50,
      "percentageUsed": 5,
      "temperatureKelvin": 323,
      "temperatureCelsius": 49.85,
      "temperatureFahrenheit": 121.73,
      "dataUnitsWrittenRaw": 67539109,
      "dataUnitsReadRaw": 117270574,
      "dataUnitsWrittenTotal": 67539109,
      "dataUnitsReadTotal": 117270574,
      "tbw": 34.58,
      "tbr": 60.04,
      "hostReadCommands": 3814899071,
      "hostWriteCommands": 1809195195,
      "controllerBusyTimeMinutes": 9857,
      "powerCycles": 1378,
      "powerOnHours": 3287,
      "unsafeShutdowns": 88,
      "mediaErrors": 0,
      "numErrorInfoEntries": 0
    }
  }
]
```

`nvmeMetrics` is omitted for disks that do not expose NVMe S.M.A.R.T. keys. The CLI encoder sorts keys alphabetically; consumers should not depend on field order.

### Using DiskPulseCore

```swift
import DiskPulseCore

for report in DiskPulseScanner.scanAllDisks() {
    guard let nvme = report.nvmeMetrics else { continue }
    print("\(report.deviceIdentifier): \(nvme.healthPercentage)% health, \(nvme.tbw) TB written")
}

if let report = DiskPulseScanner.inspectDisk("disk0"),
   let nvme = report.nvmeMetrics {
    print("Temperature: \(nvme.temperatureCelsius)°C")
}
```

Add the package to your project:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/andyburhannudien/disk-pulse.git", from: "1.1.0")
]
```

`DiskReport` is `Codable`, `Identifiable`, and `Sendable`; `NVMeSMARTMetrics` and `HealthGrade` are `Codable` and `Sendable`. The SMART parser is exposed for testing:

```swift
let metrics = DiskPulseScanner.metrics(from: smartDictionary)
```

---

## Development

### Commands

| Command | Description |
|---|---|
| `make build` | Build all targets in debug configuration. |
| `make test` | Run the DiskPulseCore self-test suite. |
| `make cli` | Build the release CLI. |
| `make app` | Build, assemble, and ad-hoc sign `dist/DiskPulse.app`. |
| `make run` | Build and launch the app. |
| `make icon` | Regenerate `Resources/AppIcon.icns`. |
| `make dmg` | Create a versioned DMG and SHA-256 checksum in `dist/`. |
| `make install` | Install the already-built app and bundled CLI (run `make app` first; may require `sudo`). |
| `make clean` | Remove `.build` and `dist`. |

### Testing

```bash
make test
# equivalent to: swift run DiskPulseSelfTest
```

The suite covers TBW/TBR math (including the high word), negative 64-bit values, safe defaults for missing keys, health-grade thresholds, and model identity. It uses a small dependency-free harness because Command Line Tools installations do not always ship XCTest.

### Packaging

`scripts/build-app.sh` performs the full release pipeline:

1. Builds `DiskPulseApp` and `diskpulse` in the selected configuration (`CONFIG=release` by default).
2. Assembles the `.app` bundle with `Info.plist`, icon, and bundled CLI.
3. Removes extended attributes and signs the bundle (ad-hoc by default).

Relevant `Info.plist` values:

| Key | Value |
|---|---|
| `CFBundleIdentifier` | `dev.diskpulse.app` |
| `CFBundleExecutable` | `DiskPulseApp` |
| `LSMinimumSystemVersion` | `12.0` |
| `LSUIElement` | `true` |
| `CFBundleShortVersionString` | `1.1.0` |

### Release artifact naming

`make dmg` wraps the signed app into a compressed, read-only disk image and emits a checksum alongside it:

```
dist/DiskPulse-<version>-macos-<arch>.dmg
dist/DiskPulse-<version>-macos-<arch>.dmg.sha256
```

- `<version>` is read from `CFBundleShortVersionString` in `Resources/Info.plist`.
- `<arch>` is derived from the Mach-O binary with `lipo`: `x86_64`, `arm64`, or `universal` when multiple architectures are present.
- The image uses the `UDZO` (zlib-compressed) format on HFS+ and contains `DiskPulse.app` plus an `Applications` symlink.
- The volume is named `DiskPulse <version>`.
- The script does not modify architectures; the filename reflects the binary produced by `scripts/build-app.sh` (host architecture by default).

Example on an Intel Mac:

```
dist/DiskPulse-1.1.0-macos-x86_64.dmg
dist/DiskPulse-1.1.0-macos-x86_64.dmg.sha256
```

Verify an artifact:

```bash
cd dist
shasum -a 256 -c DiskPulse-1.1.0-macos-x86_64.dmg.sha256
```

`make dmg` signs the app bundle, but it does not notarize the DMG; notarization is a separate release step.

### Data locations

| Data | Path |
|---|---|
| Preferences | `~/Library/Preferences/dev.diskpulse.app.plist` |
| History | `~/Library/Application Support/DiskPulse/history.json` |
| Login item | `~/Library/LaunchAgents/dev.diskpulse.app.plist` |

History stores at most one sample per minute, retains 24 hours, and caps each disk at 1,440 samples.

---

## Troubleshooting

| Symptom | Resolution |
|---|---|
| **"S.M.A.R.T. details unavailable"** | Select the whole physical disk (for example `disk0`), not a partition or APFS volume. Some USB enclosures do not forward S.M.A.R.T. data at all. |
| **Notifications never appear** | Ensure DiskPulse runs from `DiskPulse.app`, enable notifications in **Settings → Alerts**, and allow DiskPulse in **System Settings → Notifications**. Use **Send Test Notification** to verify. |
| **Launch at login does not work** | Move the app to `/Applications`, then toggle the setting off and on. Verify `~/Library/LaunchAgents/dev.diskpulse.app.plist` exists. |
| **Gatekeeper blocks the app** | Right-click the app and choose **Open**, or allow it in **System Settings → Privacy & Security → Open Anyway**. For a build you downloaded, you can also remove the quarantine flag: `xattr -dr com.apple.quarantine /Applications/DiskPulse.app`. |
| **History is empty** | History is collected only while the app is running, at most once per minute. |
| **`diskutil` errors** | Confirm the disk exists: `diskutil info disk0`. Disks can disappear between enumeration and inspection. |
| **Reset all settings** | Quit the app, then run `defaults delete dev.diskpulse.app`. Delete the history folder to reset samples. |

---

## Limitations

- **Not sandboxed.** The scanner invokes `diskutil`, which is incompatible with the Mac App Store sandbox. App Store distribution would require a direct IOKit implementation.
- **NVMe-focused.** SATA drives and some USB enclosures may not expose the SMART keys required for detailed metrics.
- **History requires a running app.** There is no privileged background daemon collecting samples while DiskPulse is closed.
- **Composite temperature only.** The reported value is the NVMe composite sensor; vendors may expose additional sensors differently.
- **Path-based login item.** The LaunchAgent stores the app path, so moving the bundle requires toggling the setting again.
- **Distribution signing.** Release builds are ad-hoc signed by default and not notarized; cross-machine distribution requires a Developer ID identity and notarization.
- **Single-architecture builds.** The provided script builds for the host architecture. Use SwiftPM multi-architecture flags if a universal binary is required.

---

## Roadmap

- [x] Native NVMe S.M.A.R.T. scanning through `diskutil`
- [x] Accurate 128-bit TBW/TBR conversion
- [x] ANSI CLI dashboard
- [x] Stable JSON output
- [x] Menu bar application with popover
- [x] Dashboard window with thermal history
- [x] Native notifications with cooldowns
- [x] Launch at login and per-disk history
- [ ] Homebrew Formula (`brew install andyburhannudien/tap/diskpulse`)
- [ ] Notarized universal binary release
- [ ] Direct IOKit reader for sandbox compatibility

---

## Contributing

Issues and pull requests are welcome.

- Run `make test` before opening a pull request.
- Keep the deployment target at macOS 12 and avoid macOS 13+ APIs unless they are guarded.
- Do not add third-party dependencies without prior discussion.
- For bug reports, include the macOS version, Mac model, and the output of `diskutil info -plist disk0` with serial numbers redacted.

---

## License

Released under the [MIT License](LICENSE).

Developed by [Andy Burhannudien](https://github.com/andyburhannudien).
