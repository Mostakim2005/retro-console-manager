# Project Operating Instructions (`AGENTS.md`)
> **Notice:** This project inherits user persona, confirmation gates, and documentation blueprints from the global master `AGENTS.md`. Do not duplicate those rules here.

## 1. Project Tech Stack & Environment
* **Runtime / Host:** Windows PowerShell 5.1+ / PowerShell Core (Single-Threaded Apartment `-STA` required for WPF UI)
* **UI Engine:** Windows Presentation Foundation (WPF declarative XAML) via `PresentationFramework`, `PresentationCore`, `WindowsBase`
* **Data Model:** Dynamic in-memory compiled C# class `RetroGameItem` implementing `INotifyPropertyChanged` via `Add-Type -TypeDefinition`
* **Folder Picker:** Native Windows Forms `FolderBrowserDialog` via `System.Windows.Forms`
* **Catalog Storage:** Local JSON metadata (`games_catalog.json`) loaded via relative path
* **Launcher:** Lightweight Windows Batch wrapper (`run-retro-console-manager.bat`) invoking hidden background PowerShell instance

## 2. Mandatory Verification & Health Checks
Before committing any changes, run the automated verification checks:

```powershell
# 1. AST Parser Check & UTF-8 BOM Verification (0 Syntax Errors Required)
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {
    `$path = 'retro-console-manager.ps1'
    `$txt = [System.IO.File]::ReadAllText(`$path, [System.Text.Encoding]::UTF8)
    `$errors = `$null
    `$tokens = `$null
    `$ast = [System.Management.Automation.Language.Parser]::ParseInput(`$txt, [ref]`$tokens, [ref]`$errors)
    if (`$errors.Count -gt 0) { `$errors | ForEach-Object { Write-Error `$_ }; exit 1 }
    `$bytes = [System.IO.File]::ReadAllBytes(`$path)
    if (-not (`$bytes.Length -ge 3 -and `$bytes[0] -eq 0xEF -and `$bytes[1] -eq 0xBB -and `$bytes[2] -eq 0xBF)) {
        Write-Error 'Missing UTF-8 BOM!'; exit 1
    }
    `$nonAscii = [regex]::Matches(`$txt, '[^\x00-\x7F]').Count
    if (`$nonAscii -gt 0) { Write-Error \"Detected `$nonAscii non-ASCII characters!\"; exit 1 }
    Write-Host 'PASSED: 0 Syntax Errors, UTF-8 BOM present, 100% Pure ASCII.'
}"
```

```powershell
# 2. Automated UI Object & Data Binding Unit Test
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
    `$code = Get-Content 'retro-console-manager.ps1' -Raw
    `$testBlock = `$code -replace '\$window\.ShowDialog\(\)\s*\|\s*Out-Null', '# Test execution'
    . ([scriptblock]::Create(`$testBlock))
    if (`$displayedModels.Count -lt 50) { Write-Error 'Catalog failed to load!'; exit 1 }
    Write-Host \"PASSED: Successfully initialized WPF window with `$(`$displayedModels.Count) games.\"
}"
```

## 3. Repository Directory Structure & Conventions
* `retro-console-manager.ps1` - Main WPF application, event wiring, and download orchestrator.
* `run-retro-console-manager.bat` - Portable Windows launcher using `%~dp0`.
* `games_catalog.json` - Curated catalog of 58 PS1 & PS2 games with metadata, tags, and archive URLs.
* `storage_config.json` - User-specific storage override (git-ignored for portability).
* `docs/` - Comprehensive architecture, product intent, pivot history, and nostalgia guide.
  * `docs/PRODUCT.md` - Source of truth for active features and wishlist.
  * `docs/ARCHITECTURE.md` - Mermaid system maps, subsystem breakdowns, and extension recipes.
  * `docs/DECISIONS_AND_TRAPS.md` - Architectural pivots, rejected options, and landmines.
  * `docs/RETRO_GAMING_AND_J2ME_GUIDE.md` - Detailed preservation and emulator setup guide.

## 4. Repository-Specific Engineering Traps
* **TRAP 1: WPF Two-Way Binding Requires C# Properties:** PowerShell `[PSCustomObject]` or raw script fields silently fail WPF `Mode=TwoWay` data binding on ListView checkboxes. Always preserve the native C# `RetroGameItem` class with explicit getter/setters and `INotifyPropertyChanged`.
* **TRAP 2: RadioButton `GroupName="StorageTarget"` Across Columns:** The HDD and SSD radio buttons live in separate columns of the top bar Grid. They MUST retain identical `GroupName="StorageTarget"` to ensure single-selection mutual exclusivity.
* **TRAP 3: Pure ASCII & UTF-8 BOM Encoding:** Windows PowerShell 5.1 default console codepages mangle non-ASCII characters into mojibake artifacts (e.g. `a-?` for Unicode arrows). Keep all UI labels in pure ASCII (e.g., `^`, `v`, `[v]`) and always save `.ps1` files with UTF-8 BOM (`[System.Text.Encoding]::UTF8`).
* **TRAP 4: Variable Scope String Interpolation:** In PowerShell double-quoted strings, never place a colon directly after a variable name (`"$drive0:"`). PowerShell parses `: ` as a scope delimiter (e.g. `$global:`). Always enclose with `$($drive0):` or `${drive0}:`.
* **TRAP 5: Script-Relative Directory Resolution:** Never hardcode absolute drives for script assets. Always compute `$scriptDir` with fallback checking `$PSScriptRoot`, `$MyInvocation.MyCommand.Path`, and `(Get-Location).Path`.
* **TRAP 6: Archive.org Bot Restriction & Silent Error Swallowing:** Automated headless downloads to Archive.org frequently encounter HTTP 403/404/503 bot challenges or login locks. Never swallow or overwrite error text unconditionally on batch completion; always track failures, pump the UI dispatcher, and provide native browser opening fallback.
