# Product Intent & Feature Map (`PRODUCT.md`)
> **1-Line Summary:** The permanent source of truth for what the user wants Retro Console Manager to do and feel like, independent of how the code is currently implemented.

## 1. Core Vision & User Experience Intent
* **What This App Does (Plain English):** Retro Console Manager is a desktop hub for Windows allowing retro gaming fans to browse, multi-select, and download curated PlayStation 1 and PlayStation 2 classics, manage BIOS requirements, and route downloads to either external HDD or internal SSD storage.
* **How It Must Feel to Use:** Instantaneous, zero-flicker native desktop experience with balanced modern dark-slate visuals (`#0A0F1D`), frictionless multi-selection without complex keyboard chords, flexible storage configuration, and zero console popup windows.

---

## 2. Active Features (Do Not Break)

### [FEATURE: Symmetrical-Storage-Top-Bar] | Aliases: top bar, storage target, hdd ssd pills, drive selection
> **1-Line Summary:** Balanced 3-column top header providing symmetrical storage target indicators with live free-space metrics and double-click custom directory picking.
* **User Intention (Non-Negotiable):** The user wants clear visual symmetry between HDD and SSD targets with real-time free space metrics, and the ability to customize storage destinations without editing script files.
* **Visual / UI Behavior:** Lives in Row 0. Left column displays Hard Disk Drive with free space in a rounded pill; middle column has the centered title; right column displays Solid State Drive with free space. Double-clicking either pill opens a Windows Explorer folder selection dialog.
* **Code Anchors (Grep Targets):**
  * `retro-console-manager.ps1` -> `Refresh-StorageLabels`, `Select-CustomStorageFolder`, `rbHDD`, `rbSSD`

### [FEATURE: Frictionless-Multi-Select] | Aliases: game selection, multi select, checkboxes, batch download
> **1-Line Summary:** Two-way bound selection engine permitting checkbox clicks, left-clicks, or right-clicks anywhere on a row to select multiple games simultaneously.
* **User Intention (Non-Negotiable):** Selecting 10 or 20 games should not require holding `Ctrl` or risk losing previous selections upon a single misclick.
* **Visual / UI Behavior:** Lives in Row 1 and Row 2. Row 1 features a live selected counter (`X selected`) alongside `All`, `None`, and `Invert` buttons. Table rows highlight blue (`#1D4ED8`) when selected.
* **Code Anchors (Grep Targets):**
  * `retro-console-manager.ps1` -> `RetroGameItem`, `IsSelected`, `Update-SelectionCount`, `btnSelectAll`, `btnSelectNone`, `btnSelectInvert`

### [FEATURE: Interlinked-Filter-And-Multi-Sort] | Aliases: column sort, multi sort, console filter, graphics filter, search, priority queue
> **1-Line Summary:** Most-Recently-Changed Priority Queue (`[#1]`, `[#2]`, `[#3]`) multi-sorting engine with size-tier grouping and combinable multi-criteria filtering.
* **User Intention (Non-Negotiable):** Users should be able to filter by console (PS1/PS2), graphics style (High/Low/2D), and search keywords while simultaneously sorting by multiple columns in whatever order they click. The most recently changed sort column must immediately become Priority `#1`, and Size + Year multi-sorting must group by size tier so secondary sorts remain coherent.
* **Visual / UI Behavior:** Column headers cycle states upon clicking and dynamically display their active priority rank in cyan (`#38BDF8`), e.g., `Year (Latest) v [#1]`, `Size (Lowest) ^ [#2]`. A real-time plain-English summary of the active filter and sort pipeline is displayed in the status footer.
* **Code Anchors (Grep Targets):**
  * `retro-console-manager.ps1` -> `Refresh-GameList`, `Update-HeaderLabels`, `Update-PipelineStatus`, `$script:sortPriority`, `SizeTier`, `hdrConsole`, `hdrGraphics`, `hdrStatus`, `hdrYear`, `hdrSize`, `hdrGenre`, `hdrTitle`, `hdrNo`

### [FEATURE: Dedicated-Reset-Filters-Button] | Aliases: reset filters, clear search, default view
> **1-Line Summary:** Single-click action button in Row 1 instantly restoring all filters, search input, and multi-column sorting back to initial defaults.
* **User Intention (Non-Negotiable):** Provide an effortless way to return to the full catalog view without having to manually uncheck multiple filter dropdowns or cycle through 4 separate column headers.
* **Visual / UI Behavior:** Compact slate button (`Reset Filters`) situated in the Row 1 action bar right next to the Help `[?]` button. Clicking it resets console to All, graphics to All, status to All, clears search text, and restores `Title (A-Z) [#1]`.
* **Code Anchors (Grep Targets):**
  * `retro-console-manager.ps1` -> `btnResetFilters`, `Reset-AllFiltersAndSorts`

### [FEATURE: Real-Time-Download-Engine] | Aliases: game download, download progress, extract archive, speed meter
> **1-Line Summary:** Multi-threaded web downloader with real-time progress percentages, speed meter (MB/s), duplicate checking, and automatic `.zip` extraction.
* **User Intention (Non-Negotiable):** Downloading games must give clear visual feedback without locking the user interface, skip existing files to save bandwidth, and extract `.zip` files into `.chd` or `.iso` automatically.
* **Visual / UI Behavior:** Lives in Row 3 and Row 4. Shows an animated progress bar, percentage, downloaded vs. total MB, real-time transfer speed, and completion audio chime.
* **Code Anchors (Grep Targets):**
  * `retro-console-manager.ps1` -> `btnDownload`, `Check-GameLocation`, `pbDownload`, `lblProgress`, `lblSpeed`

### [FEATURE: Dedicated-BIOS-Launcher] | Aliases: open bios folder, emulator bios, ps1 bios, ps2 bios
> **1-Line Summary:** Single-click launcher opening the emulator BIOS directory on the currently selected storage drive.
* **User Intention (Non-Negotiable):** Emulators require BIOS files to run games; the user needs one-click access to the storage directory where BIOS files belong.
* **Visual / UI Behavior:** Button docked in Row 1 next to `Download Selected Games` with dark slate styling (`#1E293B`).
* **Code Anchors (Grep Targets):**
  * `retro-console-manager.ps1` -> `btnBios`

---

## 3. Planned Features & App-Merge Wishlist

### [WISHLIST: Emulator-Quick-Launch] | Aliases: play game, launch duckstation, launch pcsx2
> **1-Line Summary:** Context menu or action button allowing the user to launch installed games directly in DuckStation or PCSX2.
* **User Intention:** Avoid opening the emulator separately; click 'Play' directly inside Retro Console Manager.
* **Target Integration Point:** Connect to `Check-GameLocation` and detect PCSX2 / DuckStation executable paths.

### [WISHLIST: J2ME-And-PSP-Catalog-Expansion] | Aliases: j2me games, psp games, retro portable
> **1-Line Summary:** Expand curated catalog tabs to support Java Mobile (J2ME .jar) classics and PlayStation Portable (PSP .cso/.iso) titles.
* **Target Integration Point:** Extend `games_catalog.json` schema and add a top-level platform switcher.
