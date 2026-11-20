# Retro Console Manager (PS1 & PS2)

A fast, lightweight, and modern Windows desktop GUI application for managing, filtering, and downloading curated PlayStation 1 and PlayStation 2 games with one-click BIOS folder access, live sequential download progress, and flexible storage management.

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
  - **Most-Recently-Changed Multi-Sorting:** Click `Year`, `Size`, `Genre`, and `Title` headers in any sequence. Whichever column was clicked last automatically becomes Priority `[#1]`, with earlier choices shifting to `[#2]`, `[#3]`. Active sorts dynamically highlight in cyan (`#38BDF8`).
  - **Coherent Size-Tier Grouping:** Solves raw-byte tie collisions by grouping games into 5 size tiers (<500MB, 500MB-1GB, 1GB-2GB, 2GB-3.5GB, >=3.5GB) so secondary criteria (like Year or Genre) execute reliably within each tier.
  - **1-Click Reset Filters:** Dedicated `Reset Filters` button in Row 1 instantly restoring all filters, search input, and sorting back to default (`Title A-Z [#1]`). `No. v` provides a dedicated reset back to original catalog ID.
- **Frictionless Multi-Select:**
  - Click checkboxes, left-click, or right-click anywhere on a row to multi-select games without needing to hold `Ctrl`.
  - Quick action buttons: **All**, **None**, and **Invert**.
- **Sequential Download Engine:**
  - Live download progress bar (with indeterminate mode when `Content-Length` is omitted), transfer rate (MB/s), Stop/Cancel support, and atomic `.part` temp files.
  - Pre-flight disk free-space check and automatic duplicate skipping if the game is already installed on HDD or SSD.
  - Automatic zip-slip-safe `.zip` extraction with archive cleanup (extracts archive contents; does not transcode formats).
- **One-Click BIOS Folder Access:**
  - Dedicated **Open BIOS Folder** button to open the active storage target's `BIOS` directory for placing your own PCSX2 or DuckStation BIOS dumps.
- **Pure ASCII Headers & Dark Theme Chrome:**
  - Zero mojibake encoding artifacts across Windows system locales.
  - Dark-styled table headers, scrollbars, checkboxes, tooltips, and selection brushes.
- **Planned (Not Implemented):**
  - Emulator quick-launch (`Play` button for DuckStation/PCSX2) and J2ME/PSP catalog expansion (see `docs/PRODUCT.md` wishlist).

---

## Quick Start

1. Double-click **`run-retro-console-manager.bat`**.
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
- [docs/RETRO_GAMING_AND_J2ME_GUIDE.md](docs/RETRO_GAMING_AND_J2ME_GUIDE.md) - Reference guide for DuckStation, PCSX2, and J2ME setup (reference material; J2ME is not an implemented app feature).

---

## License

This software is licensed under the **PolyForm Noncommercial License 1.0.0**. See [LICENSE](LICENSE) for details.
