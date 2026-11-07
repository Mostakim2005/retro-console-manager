# Retro Console Manager (PS1 & PS2)

A fast, lightweight, and modern Windows desktop GUI application for managing, filtering, and downloading curated PlayStation 1 and PlayStation 2 games with automated BIOS setup, multi-threaded progress tracking, and flexible storage management.

Built purely with **PowerShell 5.1+**, **WPF XAML**, and **compiled in-memory C#**, requiring zero external runtimes or heavy Electron frameworks.

---

## Key Features

- **Symmetrical Balanced Top Bar:**
  - Left & Right storage pills displaying live available free space (GB).
  - Centered vibrant title with zero visual clutter.
  - Double-click either storage pill to browse and select custom target directories in Windows Explorer.
- **Interlinked Multi-Level Filtering & Sorting:**
  - **Console Filter:** Cycle between All, PS1, and PS2.
  - **Graphics Filter:** Cycle between All, High (Realistic 3D), Low (Stylized 3D), and Retro (2D).
  - **Status Filter:** Cycle between All, Available, and Installed.
  - **Live Search:** Instant keyword searching across game title, genre, and console.
  - **Combinable Multi-Sorting:** Click `Year`, `Size`, `Genre`, and `Title` headers in any sequence. Active sorts dynamically highlight in cyan (`#38BDF8`), while `No. v` acts as a master reset to catalog order.
- **Frictionless Multi-Select:**
  - Click checkboxes, left-click, or right-click anywhere on a row to multi-select games without needing to hold `Ctrl`.
  - Quick action buttons: **All**, **None**, and **Invert**.
- **Automated Download Engine:**
  - Real-time download progress bar, transfer rate (MB/s), and byte counters.
  - Automatic duplicate skipping if the game is already installed on HDD or SSD.
  - Automatic archive extraction (`.zip` to `.chd`/`.iso`) with cleanup.
  - Windows background UI thread dispatching so the application never freezes during downloads.
- **One-Click BIOS Management:**
  - Dedicated **Open BIOS Folder** button to quickly view and place required emulator BIOS files for PCSX2 or DuckStation.
- **Pure ASCII Headers & Contrast Shield:**
  - Zero mojibake encoding artifacts across all Windows system locales.
  - Immune to Windows OS high-contrast or Dark Mode theme inversions.

---

## Quick Start

1. Double-click **`run-retro-console-manager.bat`** (or use the Desktop shortcut `Retro Console Downloader.lnk`).
2. The application will start silently without console popups.
3. Select your target storage (HDD or SSD) at the top. Double-click either pill to pick a custom directory.
4. Select the games you want to download by clicking their rows or checkboxes.
5. Click **Download Selected Games**.

---

## Repository Structure

```text
Retro Console Manager/
├── retro-console-manager.ps1      # Core application, WPF UI, and download engine
├── run-retro-console-manager.bat  # Silent launcher wrapper
├── games_catalog.json             # Curated 58-game catalog metadata
├── storage_config.json            # User storage overrides (git-ignored)
├── LICENSE                        # PolyForm Noncommercial 1.0.0
├── THIRD_PARTY_NOTICES.md         # Open-source attributions
├── AGENTS.md                      # Repository instructions and engineering rules
├── README.md                      # Overview and usage instructions
└── docs/
    ├── PRODUCT.md                 # User intentions, active features & wishlist
    ├── ARCHITECTURE.md            # System map, subsystem mechanics & recipes
    ├── DECISIONS_AND_TRAPS.md     # Architectural pivots & engineering landmines
    └── RETRO_GAMING_AND_J2ME_GUIDE.md # Emulator setup & preservation guide
```

---

## Documentation Suite

- [docs/PRODUCT.md](docs/PRODUCT.md) - Permanent source of truth for features and user intent.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - Deep dive into WPF data binding, multi-sort priority algorithms, and data flows.
- [docs/DECISIONS_AND_TRAPS.md](docs/DECISIONS_AND_TRAPS.md) - Pivot history (TUI -> WPF, single sort -> interlinked multi-sort) and protected gotchas.
- [docs/RETRO_GAMING_AND_J2ME_GUIDE.md](docs/RETRO_GAMING_AND_J2ME_GUIDE.md) - Complete emulator configuration guide for DuckStation, PCSX2, and J2ME nostalgic gaming.

---

## License

This software is licensed under the **PolyForm Noncommercial License 1.0.0**. See [LICENSE](LICENSE) for details.
