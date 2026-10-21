# DiskPulse 1.1.0

Released 2026-10-21

DiskPulse 1.1.0 is the first release with a native macOS GUI. The command-line tool and the `DiskPulseCore` library remain available and share the same scanning engine.

## Highlights

- Native menu bar application for macOS 12 Monterey and later
- Popover summary and a full dashboard window
- Multi-disk support, with synthesized APFS containers filtered out
- Native notifications with per-rule cooldowns
- Launch at login, 24-hour history, and JSON export
- Versioned DMG packaging with SHA-256 checksums

## What's New

### Menu bar application

- Status item showing health percentage, temperature, or both.
- Warning icon when the drive reaches `WARNING` or `CRITICAL`.
- Popover with health gauge, wear, spare reserve, TBW/TBR, daily writes, power-on hours, media errors, and a temperature chart.
- Dashboard with a physical-disk sidebar and detailed health, thermal, endurance, and integrity sections.
- Diagnostic summary with actionable recommendations.
- Raw S.M.A.R.T. JSON with copy and export actions.
- Clickable GitHub link with a repository tooltip.

### Notifications and automation

- Thermal alerts with a configurable threshold.
- Spare-block, media-error, health-drop, and grade-drop alerts.
- Per-rule cooldowns persisted across launches.
- Launch at login via a user LaunchAgent.
- Optional history persistence at `~/Library/Application Support/DiskPulse/history.json`.

### Core and CLI

- Fixed 128-bit TBW/TBR calculation. The high data-unit word is now combined safely with the low word, and negative 64-bit values no longer trap.
- Added `dataUnitsWrittenTotal` and `dataUnitsReadTotal` to the JSON output. Existing keys remain unchanged.
- `--all` now skips synthesized APFS containers and other virtual disks.
- Added `DiskPulseScanner.scanAllDisks()` and a public SMART parser for library consumers.
- CLI version bumped to 1.1.0.

## Installation

**Requirements:** macOS 12.0 or later. This build is for Intel (`x86_64`); Apple Silicon Macs can run it through Rosetta 2 if installed.

1. Download `DiskPulse-1.1.0-macos-x86_64.dmg`.
2. Verify the checksum (optional but recommended):

   ```bash
   shasum -a 256 -c DiskPulse-1.1.0-macos-x86_64.dmg.sha256
   ```

3. Open the disk image.
4. Drag `DiskPulse.app` to the `Applications` folder.
5. Launch DiskPulse from Applications and use the menu bar icon.

The CLI is bundled inside the app:

```bash
/Applications/DiskPulse.app/Contents/Resources/diskpulse --version
diskpulse --json
```

## SHA-256

```text
779ecf31fb32f3c2bad12f6b5cda540c60880c7de9edce721e6d8425133a2ad1  DiskPulse-1.1.0-macos-x86_64.dmg
```

## Compatibility and Known Issues

- This artifact is built for `x86_64` only. A native Apple Silicon or universal build is not included in this release.
- The app is ad-hoc signed and not notarized. On other Macs, Gatekeeper may require **System Settings → Privacy & Security → Open Anyway**.
- Detailed metrics require NVMe S.M.A.R.T. data. Some SATA drives and USB enclosures do not expose it.
- History is collected only while the app is running, at most once per minute.
- The app is not sandboxed because it invokes `/usr/sbin/diskutil`; Mac App Store distribution is not supported.

## Feedback

Report bugs and feature requests at:

https://github.com/andyburhannudien/disk-pulse/issues

**Full Changelog:** https://github.com/andyburhannudien/disk-pulse/compare/c5b48f8...v1.1.0
