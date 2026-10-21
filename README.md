# ⚡ DiskPulse

> **Modern macOS SSD Health & S.M.A.R.T. Monitor**  
> *Track NVMe wear levels, Terabytes Written (TBW), temperatures, and NAND spare reserves without third-party kernel extensions.*

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-FA7343.svg?style=flat&logo=swift)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2012%2B-000000.svg?style=flat&logo=apple)](https://apple.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 📖 Overview

**DiskPulse** is a lightweight, zero-dependency storage health assessment tool designed specifically for macOS (Apple Silicon & Intel).

Most existing Mac disk monitoring tools rely on outdated kernel extensions (kexts) or charge subscription fees. DiskPulse leverages macOS's native IOKit storage properties and NVMe S.M.A.R.T. registries to extract precise physical flash memory wear indicators directly in user space.

---

## ✨ Features

- **🎯 Flash Wear & Health Score**: Real-time health percentage calculation and NAND cell wear tracking.
- **📈 TBW & TBR Tracking**: Accurately converts 128-bit NVMe data units into Terabytes Written (TBW) and Terabytes Read (TBR).
- **🌡️ Live Thermal Diagnostics**: Reads NVMe controller composite temperatures in Celsius and Fahrenheit with thermal status badges.
- **🛡️ Spare Memory Block Watch**: Monitors `AVAILABLE_SPARE` vs vendor critical thresholds to predict hardware failure before data loss occurs.
- **🚨 Media & ECC Integrity**: Flags hardware media errors and uncorrectable read/write sectors.
- **📊 Workload Analysis**: Computes average daily write rates (GB/day) based on total power-on hours.
- **🤖 JSON Output**: One-flag (`--json`) integration for menubar apps, Prometheus exporters, or shell scripts.

---

## 🖥️ Preview

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
  Host I/O Commands: 1,809,043,164 Writes | 3,814,719,286 Reads

  ─── INTEGRITY & RELIABILITY ───────────────────────────────────────────────────
  Media Errors:      0 (No bad sectors/errors)
  Error Log Entries: 0

  ─── DIAGNOSTIC SUMMARY & ADVICE ───────────────────────────────────────────────
  ✔ SSD is in prime operating condition.
  • Minimal NAND flash wear (5% utilized).
  • Spare block reserves are at 99%, indicating zero physical cell depletion.
  • ECC reporting shows zero unrecoverable read/write failures.
  ──────────────────────────────────────────────────────────────────────────────────
```

---

## 🛠️ Building & Installation

### Requirements
- macOS 12.0 (Monterey) or newer
- Swift 5.9+ / Xcode Command Line Tools (`xcode-select --install`)

### Build from Source
```bash
# Clone the repository
git clone https://github.com/andyburhannudien/disk-pulse.git
cd disk-pulse

# Compile optimized release binary
swift build -c release

# (Optional) Install to /usr/local/bin
sudo cp .build/release/diskpulse /usr/local/bin/
```

---

## 🚀 Usage

```bash
# Scan physical disk and display visual dashboard
diskpulse

# Output clean, structured JSON
diskpulse --json

# Scan a specific disk identifier
diskpulse --disk disk0

# Scan all detected system disks
diskpulse --all

# Display help and available options
diskpulse --help
```

---

## 📦 Using as a Swift Package

You can use `DiskPulseCore` in your own macOS or SwiftUI projects:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/andyburhannudien/disk-pulse.git", from: "1.0.0")
]
```

```swift
import DiskPulseCore

if let report = DiskPulseScanner.inspectDisk("disk0") {
    if let nvme = report.nvmeMetrics {
        print("Health: \(nvme.healthPercentage)%")
        print("TBW: \(nvme.tbw) TB")
        print("Temp: \(nvme.temperatureCelsius) °C")
    }
}
```

---

## 🗺️ Roadmap

- [x] Native NVMe S.M.A.R.T. parser via macOS IOKit
- [x] Accurate 128-bit TBW/TBR computation
- [x] CLI Terminal UI with ANSI formatting
- [x] JSON output format
- [ ] SwiftUI Menu Bar application (`MenuBarExtra`)
- [ ] Desktop notifications for thermal spikes (> 65°C) and health degradation
- [ ] Homebrew Formula distribution (`brew install andyburhannudien/tap/diskpulse`)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Developed with ❤️ by [Andy Burhannudien](https://github.com/andyburhannudien).
