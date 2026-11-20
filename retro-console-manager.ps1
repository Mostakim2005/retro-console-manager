# =====================================================================
# RETRO CONSOLE GAME MANAGER - REFINED MODERN GUI (V4)
# - Balanced Header Bar: Title Center, Storage Left & Right Symmetry
# - Action Bar: Search, Multi-Select, Reset Filters, [?] Help, BIOS & Download
# - Most-Recently-Changed Priority Queue Multi-Sorting ([#1], [#2], [#3])
# - Coherent Size-Tier Grouping (Solves Raw-Byte Tie Problem)
# - Double-Click Custom Storage Target Selector & Portable Config
# - Pure ASCII Headers (100% Fix for Mojibake Artifacts like 'a-?')
# - Zero Contrast Inversion across Windows Themes
# =====================================================================

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# Enable Per-Monitor DPI Awareness v2 to prevent blurry scaling on 125%/150% displays
if (-not ("Win32.DpiAwareness" -as [type])) {
    try {
        Add-Type -Namespace Win32 -Name DpiAwareness -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool SetProcessDpiAwarenessContext(System.IntPtr value);
'@
    } catch {}
}
try { [void][Win32.DpiAwareness]::SetProcessDpiAwarenessContext([IntPtr]-4) } catch {}

# --- Compile Native C# Model for High-Performance Two-Way WPF Binding ---
$csharpModel = @"
using System;
using System.ComponentModel;

public class RetroGameItem : INotifyPropertyChanged {
    private bool _isSelected;
    public string Id { get; set; }
    public string Platform { get; set; }
    public string Title { get; set; }
    public string Year { get; set; }
    public string Genre { get; set; }
    public string Graphics { get; set; }
    public string Size { get; set; }
    public double SizeBytes { get; set; }
    public int SizeTier { get; set; }
    public string Status { get; set; }
    public object RawItem { get; set; }

    public bool IsSelected {
        get { return _isSelected; }
        set {
            if (_isSelected != value) {
                _isSelected = value;
                OnPropertyChanged("IsSelected");
            }
        }
    }

    public event PropertyChangedEventHandler PropertyChanged;
    protected void OnPropertyChanged(string name) {
        if (PropertyChanged != null) {
            PropertyChanged(this, new PropertyChangedEventArgs(name));
        }
    }
}
"@

$script:logFile = Join-Path $env:LOCALAPPDATA "RetroConsoleManager\app.log"

function Write-AppLog([string]$message, [string]$level = "INFO") {
    try {
        $dir = Split-Path -Parent $script:logFile
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        if ((Test-Path -LiteralPath $script:logFile) -and ((Get-Item -LiteralPath $script:logFile).Length -gt 2MB)) {
            Move-Item -LiteralPath $script:logFile -Destination "$($script:logFile).1" -Force
        }
        "{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}" -f (Get-Date), $level, $message |
            Add-Content -LiteralPath $script:logFile -Encoding UTF8
    } catch {}
}

if (-not ("RetroGameItem" -as [type])) {
    Add-Type -TypeDefinition $csharpModel -ErrorAction Stop
}

# --- Storage & Path Configuration (Relative, Portable & PS2EXE-Safe) ---
function Get-AppRoot {
    if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot "games_catalog.json"))) {
        return $PSScriptRoot
    }
    if ($MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
        $invDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        if (Test-Path -LiteralPath (Join-Path $invDir "games_catalog.json")) { return $invDir }
    }
    try {
        $exeDir = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
        if ($exeDir -and (Test-Path -LiteralPath (Join-Path $exeDir "games_catalog.json"))) { return $exeDir }
    } catch {}
    $cur = (Get-Location).Path
    if (Test-Path -LiteralPath (Join-Path $cur "games_catalog.json")) { return $cur }
    if ($PSScriptRoot) { return $PSScriptRoot }
    throw "Cannot resolve script directory containing games_catalog.json. Run via run-retro-console-manager.bat."
}

$scriptDir = Get-AppRoot
$jsonFile = Join-Path $scriptDir "games_catalog.json"
$configFile = Join-Path $scriptDir "storage_config.json"

$script:storageFailures = @{}

function Ensure-DestFolder([string]$path) {
    try {
        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -ItemType Directory -Path $path -Force -ErrorAction Stop | Out-Null
        }
        return $true
    } catch {
        Write-AppLog "Ensure-DestFolder failed for '$path': $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-FolderWritable([string]$path) {
    if (-not (Ensure-DestFolder $path)) { return $false }
    $probe = Join-Path $path (".write-test-" + [guid]::NewGuid().ToString("N") + ".tmp")
    try {
        [System.IO.File]::WriteAllText($probe, "ok")
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        Write-AppLog "Test-FolderWritable failed for '$path': $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Load-StorageConfig {
    $defaultLeft  = if (Test-Path -LiteralPath "E:\") { "E:\Cracked\Console_Games" } else { Join-Path $env:USERPROFILE "Retro_Games\Primary_Storage" }
    $defaultRight = Join-Path $env:USERPROFILE "Retro_Games\Console_Games"

    $cfgLeft = $defaultLeft
    $cfgRight = $defaultRight

    if (Test-Path -LiteralPath $configFile) {
        try {
            $loaded = Get-Content -LiteralPath $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($loaded.LeftPath -and (-not [string]::IsNullOrWhiteSpace($loaded.LeftPath))) {
                $cfgLeft = $loaded.LeftPath
            }
            if ($loaded.RightPath -and (-not [string]::IsNullOrWhiteSpace($loaded.RightPath))) {
                $cfgRight = $loaded.RightPath
            }
        } catch {
            Write-AppLog "Load-StorageConfig failed to parse '$configFile': $($_.Exception.Message)" "WARN"
        }
    }

    $leftDrive = try { ([System.IO.Path]::GetPathRoot($cfgLeft)).Substring(0,1).ToUpper() } catch { "E" }
    $rightDrive = try { ([System.IO.Path]::GetPathRoot($cfgRight)).Substring(0,1).ToUpper() } catch { "C" }

    $script:storageList = @(
        @{ Key = "HDD"; Name = "Hard Disk Drive"; Path = $cfgLeft; Drive = $leftDrive },
        @{ Key = "SSD"; Name = "Solid State Drive"; Path = $cfgRight; Drive = $rightDrive }
    )
}

function Save-StorageConfig {
    try {
        $cfgObj = [ordered]@{
            LeftPath  = $script:storageList[0].Path
            RightPath = $script:storageList[1].Path
        }
        $jsonOut = $cfgObj | ConvertTo-Json -Depth 4
        [System.IO.File]::WriteAllText($configFile, $jsonOut, [System.Text.Encoding]::UTF8)
    } catch {
        Write-AppLog "Save-StorageConfig failed for '$configFile': $($_.Exception.Message)" "ERROR"
    }
}

function Ensure-StorageFolders {
    $script:storageFailures = @{}
    foreach ($s in $script:storageList) {
        try {
            $root = [System.IO.Path]::GetPathRoot($s.Path)
            if ($root -and $root.Length -ge 1) {
                $s.Drive = $root.Substring(0,1).ToUpper()
            }
        } catch {
            Write-AppLog "Ensure-StorageFolders root parse failed for '$($s.Path)': $($_.Exception.Message)" "WARN"
        }
        foreach ($sub in @("PS1", "PS2", "BIOS")) {
            $p = Join-Path $s.Path $sub
            if (-not (Ensure-DestFolder $p)) {
                $script:storageFailures[$s.Key] = "Cannot create/write folder '$p' (double-click pill to choose a writable folder)."
                break
            }
        }
    }
}

Load-StorageConfig
Ensure-StorageFolders

function ConvertTo-SizeBytes([string]$sizeText) {
    if ($sizeText -notmatch '^\s*(?<n>\d+(?:\.\d+)?)\s*(?<u>KB|MB|GB)\s*$') {
        throw "Unparseable catalog size '$sizeText' (expected e.g. '450 MB' or '1.2 GB')."
    }
    $mult = switch ($Matches.u.ToUpperInvariant()) {
        "KB" { 1KB }
        "MB" { 1MB }
        "GB" { 1GB }
    }
    return ([double]$Matches.n * $mult)
}

function Assert-CatalogRecord($item) {
    if ([string]::IsNullOrWhiteSpace($item.title)) { throw "Catalog id $($item.id): missing title." }
    if ($item.platform -notin @("PS1", "PS2")) { throw "Catalog id $($item.id): unsupported platform '$($item.platform)'." }
    if ([string]::IsNullOrWhiteSpace($item.fileName)) { throw "Catalog id $($item.id): missing fileName." }
    $leaf = [System.IO.Path]::GetFileName($item.fileName)
    if ($leaf -ne $item.fileName -or $leaf -match '[\\/:*?"<>|]') {
        throw "Catalog id $($item.id): unsafe fileName '$($item.fileName)'."
    }
    $u = $null
    if (-not [System.Uri]::TryCreate($item.url, [System.UriKind]::Absolute, [ref]$u)) {
        throw "Catalog id $($item.id): URL is not absolute."
    }
    if ($u.Scheme -ne "https") {
        throw "Catalog id $($item.id): URL must use https (got $($u.Scheme))."
    }
    if ($u.Host -ne "archive.org" -and $u.Host -notlike "*.archive.org") {
        throw "Catalog id $($item.id): URL host '$($u.Host)' is not allowlisted."
    }
    if (-not $item.year -or -not $item.graphics) {
        throw "Catalog id $($item.id): missing required year or graphics field."
    }
}

function Get-Catalog {
    if (-not (Test-Path -LiteralPath $jsonFile)) {
        $msg = "Catalog file not found: $jsonFile`n`ngames_catalog.json must sit next to retro-console-manager.ps1."
        Write-AppLog $msg "ERROR"
        [System.Windows.MessageBox]::Show($msg, "Catalog Missing", "OK", "Error") | Out-Null
        throw $msg
    }
    try {
        $raw = Get-Content -LiteralPath $jsonFile -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $msg = "Catalog JSON is invalid ($jsonFile): $($_.Exception.Message)"
        Write-AppLog $msg "ERROR"
        [System.Windows.MessageBox]::Show($msg, "Catalog Corrupt", "OK", "Error") | Out-Null
        throw $msg
    }
    $items = @($raw)
    if ($items.Count -eq 0) {
        $msg = "Catalog contains no game entries: $jsonFile"
        Write-AppLog $msg "ERROR"
        [System.Windows.MessageBox]::Show($msg, "Empty Catalog", "OK", "Error") | Out-Null
        throw $msg
    }
    $valid = @()
    $bad = @()
    foreach ($item in $items) {
        try {
            Assert-CatalogRecord $item
            $bytes = ConvertTo-SizeBytes $item.size
            $item | Add-Member -NotePropertyName "SizeBytes" -NotePropertyValue $bytes -Force
            $tier = if ($bytes -lt (500 * 1024 * 1024)) { 1 }
                    elseif ($bytes -lt (1024 * 1024 * 1024)) { 2 }
                    elseif ($bytes -lt (2 * 1024 * 1024 * 1024)) { 3 }
                    elseif ($bytes -lt (3.5 * 1024 * 1024 * 1024)) { 4 }
                    else { 5 }
            $item | Add-Member -NotePropertyName "SizeTier" -NotePropertyValue $tier -Force
            $valid += $item
        } catch {
            $bad += $_.Exception.Message
            Write-AppLog "Skipped invalid catalog entry: $($_.Exception.Message)" "WARN"
        }
    }
    if ($bad.Count -gt 0) {
        $summary = ($bad | Select-Object -First 8) -join "`n"
        [System.Windows.MessageBox]::Show("Skipped $($bad.Count) invalid catalog record(s):`n`n$summary", "Catalog Validation Warning", "OK", "Warning") | Out-Null
    }
    return $valid
}

$script:libraryIndex = $null
$script:gameExtensions = @(".chd", ".iso", ".bin", ".cue", ".m3u", ".pbp", ".gz", ".zip")

function ConvertTo-MatchKey([string]$name) {
    if ([string]::IsNullOrWhiteSpace($name)) { return "" }
    $n = [System.IO.Path]::GetFileNameWithoutExtension($name)
    $n = $n -replace '\s*\((USA|Europe|Japan|Rev\s*\d+|Disc\s*\d+|Arcade Mode|En,Fr,De[^)]*)\)', ''
    return ($n -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
}

function Get-LibraryIndex {
    $idx = @{}
    foreach ($s in $script:storageList) {
        foreach ($sub in @("PS1", "PS2")) {
            $dir = Join-Path $s.Path $sub
            if (-not (Test-Path -LiteralPath $dir)) { continue }
            try {
                foreach ($f in [System.IO.Directory]::EnumerateFiles($dir, "*", [System.IO.SearchOption]::AllDirectories)) {
                    $ext = [System.IO.Path]::GetExtension($f).ToLowerInvariant()
                    if ($ext -notin $script:gameExtensions) { continue }
                    $fileName = [System.IO.Path]::GetFileName($f)
                    $k = ConvertTo-MatchKey $fileName
                    if ($k.Length -lt 4) { continue }
                    $composite = "$sub|$k"
                    if (-not $idx.ContainsKey($composite)) { $idx[$composite] = @() }
                    $idx[$composite] += [pscustomobject]@{
                        Slot     = $s.Key
                        FullPath = $f
                        Ext      = $ext
                    }
                }
            } catch {}
        }
    }
    return $idx
}

function Get-LibraryIndexCached {
    if ($null -eq $script:libraryIndex) {
        $script:libraryIndex = Get-LibraryIndex
    }
    return $script:libraryIndex
}

function Reset-LibraryIndexCache {
    $script:libraryIndex = $null
}

function Resolve-GameEntry($item, $index = $null) {
    if ($null -eq $index) { $index = Get-LibraryIndexCached }
    $subDir = if ($item.platform -eq "PS1") { "PS1" } else { "PS2" }
    $fileKey = ConvertTo-MatchKey $item.fileName
    if ($fileKey.Length -ge 4) {
        $comp = "$subDir|$fileKey"
        if ($index.ContainsKey($comp)) { return $index[$comp][0] }
    }
    $titleKey = ConvertTo-MatchKey $item.title
    if ($titleKey.Length -ge 6) {
        $comp = "$subDir|$titleKey"
        if ($index.ContainsKey($comp)) { return $index[$comp][0] }
    }
    return $null
}

function Check-GameLocation($item, $index = $null) {
    $entry = Resolve-GameEntry $item $index
    if ($null -ne $entry) { return $entry.Slot }
    return $null
}

function Get-FreeSpaceGB($driveLetter) {
    try {
        $d = Get-PSDrive $driveLetter -ErrorAction SilentlyContinue
        if ($d -and $null -ne $d.Free) { return [math]::Round($d.Free / 1GB, 1) }
    } catch {
        Write-AppLog "Get-FreeSpaceGB failed for drive $($driveLetter): $($_.Exception.Message)" "WARN"
    }
    return $null
}

function Expand-GameArchive([string]$archivePath, [string]$destFolder) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $destFull = [System.IO.Path]::GetFullPath($destFolder).TrimEnd('') + ''
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    $extractedGameFile = $false
    try {
        foreach ($entry in $zip.Entries) {
            $target = [System.IO.Path]::GetFullPath((Join-Path $destFolder $entry.FullName))
            if (-not $target.StartsWith($destFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Archive entry escapes destination folder: $($entry.FullName)"
            }
            if ([string]::IsNullOrEmpty($entry.Name)) {
                [void][System.IO.Directory]::CreateDirectory($target)
                continue
            }
            [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target))
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
            $ext = [System.IO.Path]::GetExtension($entry.Name).ToLowerInvariant()
            if ($ext -in @(".chd", ".iso", ".bin", ".cue", ".m3u", ".pbp", ".gz")) {
                $extractedGameFile = $true
            }
        }
    } finally {
        $zip.Dispose()
    }
    if (-not $extractedGameFile) {
        Write-AppLog "Archive '$archivePath' extracted without a recognized game image extension." "WARN"
    }
}

function Enable-ModernTls {
    $protos = [System.Net.SecurityProtocolType]::Tls12
    try {
        $tls13 = [System.Net.SecurityProtocolType]"Tls13"
        if ($null -ne $tls13) { $protos = $protos -bor $tls13 }
    } catch {
        Write-AppLog "TLS 1.3 enum unavailable on this .NET runtime; using TLS 1.2." "INFO"
    }
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = $protos
    } catch {
        Write-AppLog "Enable-ModernTls failed: $($_.Exception.Message)" "WARN"
    }
}

Enable-ModernTls

function Open-UrlInBrowser([string]$url) {
    if ([string]::IsNullOrWhiteSpace($url)) { return }
    $u = $null
    if (-not [System.Uri]::TryCreate($url, [System.UriKind]::Absolute, [ref]$u)) {
        Write-AppLog "Blocked invalid URL: $url" "WARN"
        if ($lblStatus) { $lblStatus.Text = "Blocked invalid URL." }
        return
    }
    if ($u.Scheme -ne "https" -and $u.Scheme -ne "http") {
        Write-AppLog "Blocked non-web URL scheme ($($u.Scheme)): $url" "WARN"
        if ($lblStatus) { $lblStatus.Text = "Blocked non-web URL scheme: $($u.Scheme)" }
        return
    }
    try {
        Start-Process -FilePath $u.AbsoluteUri
    } catch {
        Write-AppLog "Open-UrlInBrowser failed for '$($u.AbsoluteUri)': $($_.Exception.Message)" "ERROR"
        [System.Windows.MessageBox]::Show("Could not open browser for URL:`n$($u.AbsoluteUri)`n`nError: $($_.Exception.Message)", "Browser Error", "OK", "Warning") | Out-Null
    }
}

# --- XAML User Interface Layout ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Retro Console Game Manager (PS1 &amp; PS2)" Height="780" Width="1180"
        MinHeight="600" MinWidth="1040"
        UseLayoutRounding="True" SnapsToDevicePixels="True"
        WindowStartupLocation="CenterScreen" Background="#0A0F1D" Foreground="#F1F5F9"
        FontFamily="Segoe UI" FontSize="13">
    <Window.Resources>
        <!-- Semantic Theme Tokens -->
        <SolidColorBrush x:Key="Bg.Window"     Color="#0A0F1D"/>
        <SolidColorBrush x:Key="Bg.Surface"    Color="#111827"/>
        <SolidColorBrush x:Key="Bg.Table"      Color="#090E1A"/>
        <SolidColorBrush x:Key="Bg.RowAlt"     Color="#0C1220"/>
        <SolidColorBrush x:Key="Fg.Primary"    Color="#F1F5F9"/>
        <SolidColorBrush x:Key="Fg.Secondary"  Color="#94A3B8"/>
        <SolidColorBrush x:Key="Accent"        Color="#38BDF8"/>
        <SolidColorBrush x:Key="Border.Subtle" Color="#1F2937"/>
        <SolidColorBrush x:Key="Success"       Color="#10B981"/>
        <SolidColorBrush x:Key="Warn"          Color="#FBBF24"/>
        <SolidColorBrush x:Key="Danger"        Color="#F43F5E"/>

        <!-- Contrast Inversion Shield: Overrides OS theme brush colors -->
        <SolidColorBrush x:Key="{x:Static SystemColors.HighlightBrushKey}" Color="#1D4ED8"/>
        <SolidColorBrush x:Key="{x:Static SystemColors.HighlightTextBrushKey}" Color="#FFFFFF"/>
        <SolidColorBrush x:Key="{x:Static SystemColors.InactiveSelectionHighlightBrushKey}" Color="#1E293B"/>
        <SolidColorBrush x:Key="{x:Static SystemColors.InactiveSelectionHighlightTextBrushKey}" Color="#FFFFFF"/>

        <!-- Standard Button Style -->
        <Style TargetType="Button">
            <Setter Property="Background" Value="#1E293B"/>
            <Setter Property="Foreground" Value="#F8FAFC"/>
            <Setter Property="BorderBrush" Value="#334155"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Name="BtnBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="5" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="BtnBorder" Property="Background" Value="#334155"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="BtnBorder" Property="Background" Value="#475569"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Large Storage Pill RadioButtons -->
        <Style x:Key="LargeStoragePill" TargetType="RadioButton">
            <Setter Property="Foreground" Value="#E2E8F0"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Margin" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RadioButton">
                        <Border Name="PillBorder" Background="#1E293B" BorderBrush="#334155" BorderThickness="1.5" CornerRadius="18" Padding="14,6">
                            <StackPanel Orientation="Horizontal">
                                <Ellipse Name="PillDot" Width="9" Height="9" Fill="#64748B" Margin="0,0,8,0" VerticalAlignment="Center"/>
                                <ContentPresenter VerticalAlignment="Center"/>
                            </StackPanel>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="PillBorder" Property="Background" Value="#0F2D59"/>
                                <Setter TargetName="PillBorder" Property="BorderBrush" Value="#38BDF8"/>
                                <Setter TargetName="PillDot" Property="Fill" Value="#38BDF8"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="PillBorder" Property="Background" Value="#2A3B53"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Custom ListViewItem: Checkbox-Model Authoritative Highlight (No Selector Conflict) -->
        <Style TargetType="ListViewItem">
            <Setter Property="SnapsToDevicePixels" Value="True"/>
            <Setter Property="Padding" Value="4,6"/>
            <Setter Property="Margin" Value="0,1"/>
            <Setter Property="Foreground" Value="#E2E8F0"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListViewItem">
                        <Border Name="RowBorder" Background="{TemplateBinding Background}" CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <GridViewRowPresenter Columns="{TemplateBinding GridView.ColumnCollection}" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="ItemsControl.AlternationIndex" Value="1">
                                <Setter TargetName="RowBorder" Property="Background" Value="#0C1220"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="RowBorder" Property="Background" Value="#1E293B"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <DataTrigger Binding="{Binding IsSelected}" Value="True">
                                <Setter TargetName="RowBorder" Property="Background" Value="#1D4ED8"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </DataTrigger>
                            <MultiDataTrigger>
                                <MultiDataTrigger.Conditions>
                                    <Condition Binding="{Binding IsSelected}" Value="True"/>
                                    <Condition Binding="{Binding RelativeSource={RelativeSource Self}, Path=IsMouseOver}" Value="True"/>
                                </MultiDataTrigger.Conditions>
                                <Setter TargetName="RowBorder" Property="Background" Value="#2563EB"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </MultiDataTrigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Column Header Buttons (Pure ASCII: Zero Artifacts) -->
        <Style x:Key="HeaderBtn" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#94A3B8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="4,2"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Foreground" Value="#38BDF8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Dark GridViewColumnHeader Style (Fixes System-Light Header Band) -->
        <Style TargetType="GridViewColumnHeader">
            <Setter Property="Background" Value="#111827"/>
            <Setter Property="Foreground" Value="#94A3B8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="4,6"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="GridViewColumnHeader">
                        <Border Name="HdrBorder" Background="{TemplateBinding Background}"
                                BorderBrush="#1F2937" BorderThickness="0,0,0,1"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="HdrBorder" Property="Background" Value="#1E293B"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Dark ToolTip Style -->
        <Style TargetType="ToolTip">
            <Setter Property="Background" Value="#111827"/>
            <Setter Property="Foreground" Value="#E2E8F0"/>
            <Setter Property="BorderBrush" Value="#334155"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,5"/>
        </Style>

        <!-- Dark CheckBox Style -->
        <Style TargetType="CheckBox">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
            <Setter Property="HorizontalAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Border Name="Box" Width="16" Height="16" CornerRadius="3"
                                Background="#0B1220" BorderBrush="#475569" BorderThickness="1.5">
                            <Path Name="CheckMark" Data="M 2,6 L 5,9 L 11,2" Stroke="#38BDF8" StrokeThickness="2"
                                  StrokeStartLineCap="Round" StrokeEndLineCap="Round" Visibility="Collapsed"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="CheckMark" Property="Visibility" Value="Visible"/>
                                <Setter TargetName="Box" Property="BorderBrush" Value="#38BDF8"/>
                                <Setter TargetName="Box" Property="Background" Value="#0F2D59"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Box" Property="BorderBrush" Value="#94A3B8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Dark ScrollBar Style -->
        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="#0B1220"/>
            <Setter Property="Width" Value="10"/>
            <Setter Property="MinWidth" Value="10"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Border Background="{TemplateBinding Background}" CornerRadius="5">
                            <Track Name="PART_Track" IsDirectionReversed="True">
                                <Track.Thumb>
                                    <Thumb>
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Border Name="ThumbBorder" Background="#334155" CornerRadius="4" Margin="1"/>
                                                <ControlTemplate.Triggers>
                                                    <Trigger Property="IsMouseOver" Value="True">
                                                        <Setter TargetName="ThumbBorder" Property="Background" Value="#475569"/>
                                                    </Trigger>
                                                </ControlTemplate.Triggers>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                            </Track>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="Orientation" Value="Horizontal">
                    <Setter Property="Width" Value="Auto"/>
                    <Setter Property="Height" Value="10"/>
                    <Setter Property="MinHeight" Value="10"/>
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="ScrollBar">
                                <Border Background="{TemplateBinding Background}" CornerRadius="5">
                                    <Track Name="PART_Track" IsDirectionReversed="False">
                                        <Track.Thumb>
                                            <Thumb>
                                                <Thumb.Template>
                                                    <ControlTemplate TargetType="Thumb">
                                                        <Border Name="ThumbBorder" Background="#334155" CornerRadius="4" Margin="1"/>
                                                        <ControlTemplate.Triggers>
                                                            <Trigger Property="IsMouseOver" Value="True">
                                                                <Setter TargetName="ThumbBorder" Property="Background" Value="#475569"/>
                                                            </Trigger>
                                                        </ControlTemplate.Triggers>
                                                    </ControlTemplate>
                                                </Thumb.Template>
                                            </Thumb>
                                        </Track.Thumb>
                                    </Track>
                                </Border>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <Grid Margin="14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- Row 0: Merged Balanced Top Bar (Storage Left, Title Center, Storage Right) -->
            <RowDefinition Height="Auto"/> <!-- Row 1: Search + Multi-Select + Reset + Help + BIOS + Download Action Bar -->
            <RowDefinition Height="*"/>    <!-- Row 2: Games Table -->
            <RowDefinition Height="Auto"/> <!-- Row 3: Progress Bar -->
            <RowDefinition Height="Auto"/> <!-- Row 4: Status Footer -->
        </Grid.RowDefinitions>

        <!-- ROW 0: MERGED BALANCED TOP BAR (SYMMETRIC STORAGE PILLS) -->
        <Border Grid.Row="0" Background="#111827" CornerRadius="8" Padding="14,10" Margin="0,0,0,10" BorderBrush="#1F2937" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <!-- Column 0 (Left): Hard Disk Drive Storage Pill -->
                <StackPanel Grid.Column="0" Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Center">
                    <RadioButton Name="rbHDD" GroupName="StorageTarget" Content="" Style="{StaticResource LargeStoragePill}" IsChecked="True"/>
                </StackPanel>

                <!-- Column 1 (Middle): App Title (Centered) -->
                <TextBlock Grid.Column="1" Text="RETRO CONSOLE MANAGER" FontWeight="Bold" FontSize="16" Foreground="#38BDF8"
                           VerticalAlignment="Center" HorizontalAlignment="Center" Margin="12,0"/>

                <!-- Column 2 (Right): Solid State Drive Storage Pill -->
                <StackPanel Grid.Column="2" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                    <RadioButton Name="rbSSD" GroupName="StorageTarget" Content="" Style="{StaticResource LargeStoragePill}"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- ROW 1: SEARCH, MULTI-SELECT, RESET, HELP & DOWNLOAD ACTION BAR -->
        <Border Grid.Row="1" Background="#111827" CornerRadius="6" Padding="14,8" Margin="0,0,0,8" BorderBrush="#1F2937" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <WrapPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="0,2,14,2">
                        <TextBlock Text="Search:" VerticalAlignment="Center" Foreground="#94A3B8" Margin="0,0,8,0" FontWeight="SemiBold"/>
                        <TextBox Name="txtSearch" Width="180" Background="#1E293B" Foreground="#F8FAFC" BorderBrush="#334155"
                                 CaretBrush="#38BDF8" Padding="8,4" VerticalAlignment="Center"
                                 ToolTip="Type keyword to filter games by title, genre, or system (Esc to clear)"/>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="0,2,0,2">
                        <TextBlock Text="Select:" Foreground="#94A3B8" VerticalAlignment="Center" Margin="0,0,6,0" FontWeight="SemiBold"/>
                        <Button Name="btnSelectAll" Content="All" Margin="0,0,4,0" Padding="8,4"/>
                        <Button Name="btnSelectNone" Content="None" Margin="0,0,4,0" Padding="8,4"/>
                        <Button Name="btnSelectInvert" Content="Invert" Margin="0,0,4,0" Padding="8,4"/>
                        <Button Name="btnClearAllSel" Content="Clear All" Margin="0,0,8,0" Padding="8,4" ToolTip="Clear all selections including any hidden by active filters"/>
                        <TextBlock Name="lblSelectionCount" Text="0 selected" Foreground="#38BDF8" FontWeight="Bold" VerticalAlignment="Center" Margin="0,0,8,0"/>
                        <Button Name="btnHelp" Content="?" Width="26" Height="26" Padding="0" Margin="0,0,6,0" FontWeight="Bold"
                                Foreground="#38BDF8" Background="#1E293B" BorderBrush="#334155" BorderThickness="1"
                                VerticalAlignment="Center" ToolTip="Click for Controls &amp; Filter Help"/>
                        <Button Name="btnResetFilters" Content="Reset Filters" Margin="0,0,10,0" Padding="8,4"
                                Background="#1E293B" Foreground="#F8FAFC" BorderBrush="#334155"
                                ToolTip="Reset all filters, search text, and sorting back to default"/>
                    </StackPanel>
                </WrapPanel>

                <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                    <Button Name="btnBios" Content="Open BIOS Folder" Margin="0,0,8,0" Padding="12,6" Background="#1E293B" VerticalAlignment="Center"/>
                    <Button Name="btnOpenBrowser" Content="Open in Browser" Margin="0,0,8,0"
                            Background="#2563EB" Foreground="#FFFFFF" FontWeight="Bold" FontSize="13" Padding="14,7" Cursor="Hand"
                            ToolTip="Open download links for selected games directly in your default web browser for manual download"/>
                    <Button Name="btnDownload" Content="Download Selected Games"
                            Background="#10B981" Foreground="#0F172A" FontWeight="Bold" FontSize="13" Padding="14,7" Cursor="Hand"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- ROW 2: GAMES TABLE WITH CHECKBOXES & CLICKABLE PURE-ASCII HEADERS -->
        <ListView Name="lvGames" Grid.Row="2" Background="#090E1A" Foreground="#E2E8F0" BorderBrush="#1F2937" BorderThickness="1"
                  SelectionMode="Single"
                  AlternationCount="2"
                  VirtualizingStackPanel.IsVirtualizing="True"
                  VirtualizingStackPanel.VirtualizationMode="Recycling"
                  ScrollViewer.IsDeferredScrollingEnabled="False"
                  ScrollViewer.HorizontalScrollBarVisibility="Auto"
                  ScrollViewer.VerticalScrollBarVisibility="Auto">
            <ListView.ContextMenu>
                <ContextMenu Background="#1E293B" Foreground="#F8FAFC" BorderBrush="#334155">
                    <MenuItem Name="cmOpenBrowser" Header="Open Download Link in Browser" FontWeight="Bold"/>
                    <MenuItem Name="cmOpenDetails" Header="Open Archive.org Details Page"/>
                    <Separator Background="#334155"/>
                    <MenuItem Name="cmCopyUrl" Header="Copy Download URL"/>
                    <MenuItem Name="cmOpenFolder" Header="Open Local Game Folder"/>
                </ContextMenu>
            </ListView.ContextMenu>
            <ListView.View>
                <GridView>
                    <!-- Column 0: CheckBox Column -->
                    <GridViewColumn Width="40">
                        <GridViewColumn.Header>
                            <TextBlock Text="[v]" Foreground="#94A3B8" FontWeight="Bold" HorizontalAlignment="Center"/>
                        </GridViewColumn.Header>
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <CheckBox IsChecked="{Binding IsSelected, Mode=TwoWay}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>

                    <!-- Column 1: No. (Reset all sorts to catalog ID) -->
                    <GridViewColumn Width="44" DisplayMemberBinding="{Binding Id}">
                        <GridViewColumn.Header>
                            <Button Name="hdrNo" Content="No. v" Style="{StaticResource HeaderBtn}" ToolTip="Reset all sorts to Catalog ID order"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>

                    <!-- Column 2: Console (Cycles ALL / PS1 / PS2) -->
                    <GridViewColumn Width="105" DisplayMemberBinding="{Binding Platform}">
                        <GridViewColumn.Header>
                            <Button Name="hdrConsole" Content="Console: All [v]" Style="{StaticResource HeaderBtn}" Foreground="#38BDF8" ToolTip="Click to Cycle: All -> PS1 -> PS2"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>

                    <!-- Column 3: Title (Fluid width, Cycles A-Z / Z-A / Off) -->
                    <GridViewColumn Width="280" DisplayMemberBinding="{Binding Title}">
                        <GridViewColumn.Header>
                            <Button Name="hdrTitle" Content="Title (A-Z) ^ [#1]" Style="{StaticResource HeaderBtn}" Foreground="#38BDF8" ToolTip="Click to cycle Title sort (Most recently clicked becomes [#1])"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>

                    <!-- Column 4: Release Year -->
                    <GridViewColumn Width="70" DisplayMemberBinding="{Binding Year}">
                        <GridViewColumn.Header>
                            <Button Name="hdrYear" Content="Year v" Style="{StaticResource HeaderBtn}" ToolTip="Click to cycle Year sort (Most recently clicked becomes [#1])"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>

                    <!-- Column 5: Genre -->
                    <GridViewColumn Width="170" DisplayMemberBinding="{Binding Genre}">
                        <GridViewColumn.Header>
                            <Button Name="hdrGenre" Content="Genre v" Style="{StaticResource HeaderBtn}" ToolTip="Click to cycle Genre sort (Most recently clicked becomes [#1])"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>

                    <!-- Column 6: Graphics (High / Low / 2D / All) -->
                    <GridViewColumn Width="115" DisplayMemberBinding="{Binding Graphics}">
                        <GridViewColumn.Header>
                            <Button Name="hdrGraphics" Content="Graphics: All [v]" Style="{StaticResource HeaderBtn}" Foreground="#38BDF8" ToolTip="Click to Cycle: All -> High (Realistic) -> Low (Stylized) -> Retro (2D)"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>

                    <!-- Column 7: Download Size -->
                    <GridViewColumn Width="100" DisplayMemberBinding="{Binding Size}">
                        <GridViewColumn.Header>
                            <Button Name="hdrSize" Content="Size v" Style="{StaticResource HeaderBtn}" ToolTip="Click to cycle Size sort (Most recently clicked becomes [#1])"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>

                    <!-- Column 8: Status (Cycles All / Available / Installed) -->
                    <GridViewColumn Width="135" DisplayMemberBinding="{Binding Status}">
                        <GridViewColumn.Header>
                            <Button Name="hdrStatus" Content="Status: All [v]" Style="{StaticResource HeaderBtn}" Foreground="#38BDF8" ToolTip="Click to Cycle: All -> Available Only -> Installed Only"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>
                </GridView>
            </ListView.View>
        </ListView>

        <!-- ROW 3: PROGRESS BAR (Collapsed While Idle) -->
        <Border Name="pnlProgress" Grid.Row="3" Margin="0,8,0,6" Visibility="Collapsed">
            <StackPanel>
                <ProgressBar Name="pbDownload" Height="8" Background="#1E293B" Foreground="#38BDF8" BorderThickness="0" Value="0" Maximum="100"/>
                <DockPanel LastChildFill="False" Margin="0,4,0,0">
                    <TextBlock Name="lblProgress" Text="Ready" Foreground="#94A3B8" FontSize="12" VerticalAlignment="Center" DockPanel.Dock="Left"/>
                    <Button Name="btnStop" Content="Stop" Visibility="Collapsed" DockPanel.Dock="Right" Margin="10,0,0,0" Padding="10,2"
                            Background="#991B1B" Foreground="#FFFFFF" BorderBrush="#DC2626" FontSize="11"/>
                    <TextBlock Name="lblSpeed" Text="" Foreground="#FCD34D" FontSize="12" FontWeight="SemiBold" VerticalAlignment="Center" DockPanel.Dock="Right"/>
                </DockPanel>
            </StackPanel>
        </Border>

        <!-- ROW 4: FOOTER STATUS -->
        <Border Grid.Row="4" Background="#060A14" CornerRadius="4" Padding="10,6" BorderBrush="#1F2937" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Name="lblStatus" Grid.Column="0" Text="" TextTrimming="CharacterEllipsis" TextWrapping="NoWrap"
                           Foreground="#94A3B8" FontSize="12" Margin="0,0,12,0"/>
                <TextBlock Name="lblGameCount" Grid.Column="1" Text="" Foreground="#38BDF8" FontWeight="SemiBold" FontSize="12"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Get Control References
$rbHDD             = $window.FindName("rbHDD")
$rbSSD             = $window.FindName("rbSSD")
$btnBios           = $window.FindName("btnBios")
$txtSearch         = $window.FindName("txtSearch")
$btnSelectAll      = $window.FindName("btnSelectAll")
$btnSelectNone     = $window.FindName("btnSelectNone")
$btnSelectInvert   = $window.FindName("btnSelectInvert")
$btnClearAllSel    = $window.FindName("btnClearAllSel")
$lblSelectionCount = $window.FindName("lblSelectionCount")
$btnHelp           = $window.FindName("btnHelp")
$btnResetFilters   = $window.FindName("btnResetFilters")
$btnDownload       = $window.FindName("btnDownload")
$btnOpenBrowser    = $window.FindName("btnOpenBrowser")
$cmOpenBrowser     = $window.FindName("cmOpenBrowser")
$cmOpenDetails     = $window.FindName("cmOpenDetails")
$cmCopyUrl         = $window.FindName("cmCopyUrl")
$cmOpenFolder      = $window.FindName("cmOpenFolder")
$lvGames           = $window.FindName("lvGames")
$pnlProgress       = $window.FindName("pnlProgress")
$pbDownload        = $window.FindName("pbDownload")
$lblProgress       = $window.FindName("lblProgress")
$lblSpeed          = $window.FindName("lblSpeed")
$btnStop           = $window.FindName("btnStop")
$lblStatus         = $window.FindName("lblStatus")
$lblGameCount      = $window.FindName("lblGameCount")

# Column Headers
$hdrNo       = $window.FindName("hdrNo")
$hdrConsole  = $window.FindName("hdrConsole")
$hdrTitle    = $window.FindName("hdrTitle")
$hdrYear     = $window.FindName("hdrYear")
$hdrGenre    = $window.FindName("hdrGenre")
$hdrGraphics = $window.FindName("hdrGraphics")
$hdrSize     = $window.FindName("hdrSize")
$hdrStatus   = $window.FindName("hdrStatus")

# Color Brushes for Interactive Header Highlighting
$brushActive   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38BDF8")
$brushInactive = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#94A3B8")
$brushPurple   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A78BFA")
$brushGreen    = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
$brushRose     = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F43F5E")
$brushAmber    = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FBBF24")
$brushViolet   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A855F7")
$brushEmerald       = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
$brushDownloadIdle  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
$brushDownloadReady = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#059669")
$brushBrowserBlue   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2563EB")

$script:contextModel        = $null
$script:suppressCount       = $false
$script:suppressTextChanged = $false
$script:selectedIds         = New-Object System.Collections.Generic.HashSet[int]

$allCatalog = Get-Catalog

# Filter & Sort States
$script:consoleState      = 0   # 0 = All, 1 = PS1, 2 = PS2
$script:graphicsState     = 0   # 0 = All, 1 = High, 2 = Low, 3 = 2D
$script:statusFilterState = 0   # 0 = All, 1 = Available, 2 = Installed

$script:titleSortState    = 1   # 1 = Title A-Z (Default Active), 2 = Title Z-A, 0 = Off
$script:yearSortState     = 0   # 0 = Off, 1 = Latest (Desc), 2 = Oldest (Asc)
$script:sizeSortState     = 0   # 0 = Off, 1 = Lowest (Asc), 2 = Highest (Desc)
$script:genreSortState    = 0   # 0 = Off, 1 = A-Z (Asc), 2 = Z-A (Desc)

# Most-Recently-Changed Priority Queue (All 4 sortable columns)
$script:sortPriority = New-Object System.Collections.Generic.List[string]
$script:sortPriority.Add("Title")

$displayedModels = New-Object System.Collections.ObjectModel.ObservableCollection[RetroGameItem]

function Format-StorageLabel([string]$kind, $slot) {
    $leaf = Split-Path $slot.Path -Leaf
    $free = Get-FreeSpaceGB $slot.Drive
    $freeText = if ($null -eq $free) { "n/a" } else { "$free GB Free" }
    return "$kind ($($slot.Drive): $leaf) [$freeText]"
}

function Refresh-StorageLabels {
    $slot0 = $script:storageList[0]
    $slot1 = $script:storageList[1]

    $rbHDD.Content = Format-StorageLabel "Hard Disk Drive" $slot0
    $rbSSD.Content = Format-StorageLabel "Solid State Drive" $slot1

    $fail0 = $script:storageFailures[$slot0.Key]
    $fail1 = $script:storageFailures[$slot1.Key]

    $rbHDD.ToolTip = if ($fail0) { "WARNING: $fail0`nPath: $($slot0.Path)" } else { "Active Path: $($slot0.Path)`nDouble-click to browse and select a custom folder" }
    $rbSSD.ToolTip = if ($fail1) { "WARNING: $fail1`nPath: $($slot1.Path)" } else { "Active Path: $($slot1.Path)`nDouble-click to browse and select a custom folder" }

    if ($fail0 -and -not $fail1 -and $rbHDD.IsChecked) { $rbSSD.IsChecked = $true }
    elseif ($fail1 -and -not $fail0 -and $rbSSD.IsChecked) { $rbHDD.IsChecked = $true }
}

function Select-CustomStorageFolder([int]$slotIndex) {
    try {
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = "Select target folder for console games (PS1, PS2, and BIOS subfolders will be created automatically)"
        if (Test-Path $script:storageList[$slotIndex].Path) {
            $dialog.SelectedPath = $script:storageList[$slotIndex].Path
        }
        $dialog.ShowNewFolderButton = $true

        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $chosen = $dialog.SelectedPath.Trim()
            if (-not [string]::IsNullOrWhiteSpace($chosen)) {
                $script:storageList[$slotIndex].Path = $chosen
                $root = [System.IO.Path]::GetPathRoot($chosen)
                if ($root -and $root.Length -ge 1) {
                    $script:storageList[$slotIndex].Drive = $root.Substring(0,1).ToUpper()
                }
                Ensure-StorageFolders
                Save-StorageConfig
                Reset-LibraryIndexCache
                Refresh-StorageLabels
                Update-PipelineStatus
                Refresh-GameList
                $lblStatus.Text = "Updated storage path to: $chosen"
            }
        }
    } catch {
        [System.Windows.MessageBox]::Show("Error selecting folder: $($_.Exception.Message)", "Folder Selection Error", "OK", "Warning")
    }
}

$rbHDD.Add_MouseDoubleClick({
    param($sender, $e)
    $e.Handled = $true
    Select-CustomStorageFolder 0
})

$rbSSD.Add_MouseDoubleClick({
    param($sender, $e)
    $e.Handled = $true
    Select-CustomStorageFolder 1
})

function Set-GameSelected([int]$id, [bool]$value) {
    if ($value) { [void]$script:selectedIds.Add($id) }
    else { [void]$script:selectedIds.Remove($id) }
}

function Get-VisibleSelectedCount {
    $c = 0
    foreach ($m in $displayedModels) {
        if ($m.IsSelected) { $c++ }
    }
    return $c
}

function Get-SelectedCatalogItems {
    return @($allCatalog | Where-Object { $script:selectedIds.Contains([int]$_.id) })
}

function Get-SelectedGames {
    $byId = @{}
    foreach ($m in $displayedModels) {
        if ($null -ne $m.RawItem) { $byId[[int]$m.RawItem.id] = $m }
    }
    $result = @()
    foreach ($item in $allCatalog) {
        $id = [int]$item.id
        if (-not $script:selectedIds.Contains($id)) { continue }
        if ($byId.ContainsKey($id)) {
            $result += $byId[$id]
        } else {
            $stub = New-Object RetroGameItem
            $stub.Id = "$($item.id)."
            $stub.Platform = $item.platform
            $stub.Title = $item.title
            $stub.Size = $item.size
            $stub.SizeBytes = $item.SizeBytes
            $stub.SizeTier = [int]$item.SizeTier
            $stub.RawItem = $item
            $stub.IsSelected = $true
            $result += $stub
        }
    }
    return $result
}

function Update-SelectionCount {
    if ($script:suppressCount) { return }
    $count = $script:selectedIds.Count
    $visCount = Get-VisibleSelectedCount
    $hiddenCount = [math]::Max(0, $count - $visCount)
    if ($hiddenCount -gt 0) {
        $lblSelectionCount.Text = "$count selected ($hiddenCount outside filter)"
    } else {
        $lblSelectionCount.Text = "$count selected"
    }
    $btnClearAllSel.IsEnabled = ($count -gt 0)
    if ($count -eq 0) {
        $btnDownload.Content = "Download Selected Games"
        $btnDownload.Background = $brushDownloadIdle
        $btnOpenBrowser.Content = "Open in Browser"
        $btnOpenBrowser.Background = $brushBrowserBlue
    } elseif ($count -eq 1) {
        $btnDownload.Content = "Download 1 Game"
        $btnDownload.Background = $brushDownloadReady
        $btnOpenBrowser.Content = "Open 1 in Browser"
        $btnOpenBrowser.Background = $brushBrowserBlue
    } else {
        $btnDownload.Content = "Download $count Games (Batch)"
        $btnDownload.Background = $brushDownloadReady
        $btnOpenBrowser.Content = "Open $count in Browser"
        $btnOpenBrowser.Background = $brushBrowserBlue
    }
}

function Update-HeaderLabels {
    # 1. Title
    if ($script:titleSortState -eq 0) {
        $hdrTitle.Content = "Title v"
        $hdrTitle.Foreground = $brushInactive
    } else {
        $rankIdx = $script:sortPriority.IndexOf("Title")
        $rankTag = if ($rankIdx -ge 0) { " [#" + ($rankIdx + 1) + "]" } else { "" }
        if ($script:titleSortState -eq 1) {
            $hdrTitle.Content = "Title (A-Z) ^$rankTag"
        } else {
            $hdrTitle.Content = "Title (Z-A) v$rankTag"
        }
        $hdrTitle.Foreground = $brushActive
    }

    # 2. Year
    if ($script:yearSortState -eq 0) {
        $hdrYear.Content = "Year v"
        $hdrYear.Foreground = $brushInactive
    } else {
        $rankIdx = $script:sortPriority.IndexOf("Year")
        $rankTag = if ($rankIdx -ge 0) { " [#" + ($rankIdx + 1) + "]" } else { "" }
        if ($script:yearSortState -eq 1) {
            $hdrYear.Content = "Year (Latest) v$rankTag"
        } else {
            $hdrYear.Content = "Year (Oldest) ^$rankTag"
        }
        $hdrYear.Foreground = $brushActive
    }

    # 3. Size
    if ($script:sizeSortState -eq 0) {
        $hdrSize.Content = "Size v"
        $hdrSize.Foreground = $brushInactive
    } else {
        $rankIdx = $script:sortPriority.IndexOf("Size")
        $rankTag = if ($rankIdx -ge 0) { " [#" + ($rankIdx + 1) + "]" } else { "" }
        if ($script:sizeSortState -eq 1) {
            $hdrSize.Content = "Size (Lowest) ^$rankTag"
        } else {
            $hdrSize.Content = "Size (Highest) v$rankTag"
        }
        $hdrSize.Foreground = $brushActive
    }

    # 4. Genre
    if ($script:genreSortState -eq 0) {
        $hdrGenre.Content = "Genre v"
        $hdrGenre.Foreground = $brushInactive
    } else {
        $rankIdx = $script:sortPriority.IndexOf("Genre")
        $rankTag = if ($rankIdx -ge 0) { " [#" + ($rankIdx + 1) + "]" } else { "" }
        if ($script:genreSortState -eq 1) {
            $hdrGenre.Content = "Genre (A-Z) ^$rankTag"
        } else {
            $hdrGenre.Content = "Genre (Z-A) v$rankTag"
        }
        $hdrGenre.Foreground = $brushActive
    }

    # Console, Graphics, Status Filter Headers
    switch ($script:consoleState) {
        0 { $hdrConsole.Content = "Console: All [v]"; $hdrConsole.Foreground = $brushActive }
        1 { $hdrConsole.Content = "Console: PS1 [v]"; $hdrConsole.Foreground = $brushPurple }
        2 { $hdrConsole.Content = "Console: PS2 [v]"; $hdrConsole.Foreground = $brushGreen }
    }

    switch ($script:graphicsState) {
        0 { $hdrGraphics.Content = "Graphics: All [v]"; $hdrGraphics.Foreground = $brushActive }
        1 { $hdrGraphics.Content = "Graphics: High [v]"; $hdrGraphics.Foreground = $brushRose }
        2 { $hdrGraphics.Content = "Graphics: Low [v]"; $hdrGraphics.Foreground = $brushAmber }
        3 { $hdrGraphics.Content = "Graphics: 2D [v]"; $hdrGraphics.Foreground = $brushViolet }
    }

    switch ($script:statusFilterState) {
        0 { $hdrStatus.Content = "Status: All [v]"; $hdrStatus.Foreground = $brushActive }
        1 { $hdrStatus.Content = "Status: Available [v]"; $hdrStatus.Foreground = $brushInactive }
        2 { $hdrStatus.Content = "Status: Installed [v]"; $hdrStatus.Foreground = $brushEmerald }
    }
}

function Update-PipelineStatus {
    $activeFilters = @()
    if ($script:consoleState -eq 1) { $activeFilters += "Console=PS1" }
    elseif ($script:consoleState -eq 2) { $activeFilters += "Console=PS2" }

    if ($script:graphicsState -eq 1) { $activeFilters += "Graphics=High" }
    elseif ($script:graphicsState -eq 2) { $activeFilters += "Graphics=Low" }
    elseif ($script:graphicsState -eq 3) { $activeFilters += "Graphics=2D" }

    if ($script:statusFilterState -eq 1) { $activeFilters += "Status=Available" }
    elseif ($script:statusFilterState -eq 2) { $activeFilters += "Status=Installed" }

    $searchTxt = $txtSearch.Text.Trim()
    if (-not [string]::IsNullOrWhiteSpace($searchTxt)) {
        $activeFilters += "Search='$searchTxt'"
    }

    $sortDescs = @()
    for ($i = 0; $i -lt $script:sortPriority.Count; $i++) {
        $col = $script:sortPriority[$i]
        $rankNum = $i + 1
        if ($col -eq "Size") {
            $dir = if ($script:sizeSortState -eq 1) { "Lowest" } else { "Highest" }
            $sortDescs += "#$rankNum Size ($dir)"
        } elseif ($col -eq "Year") {
            $dir = if ($script:yearSortState -eq 1) { "Latest" } else { "Oldest" }
            $sortDescs += "#$rankNum Year ($dir)"
        } elseif ($col -eq "Genre") {
            $dir = if ($script:genreSortState -eq 1) { "A-Z" } else { "Z-A" }
            $sortDescs += "#$rankNum Genre ($dir)"
        } elseif ($col -eq "Title") {
            $dir = if ($script:titleSortState -eq 1) { "A-Z" } else { "Z-A" }
            $sortDescs += "#$rankNum Title ($dir)"
        }
    }

    $isDefault = ($activeFilters.Count -eq 0 -and $sortDescs.Count -eq 1 -and $sortDescs[0] -eq "#1 Title (A-Z)")
    if ($isDefault) {
        $lblStatus.Text = "Ready. Default (Title A-Z)"
    } else {
        $filterPart = if ($activeFilters.Count -gt 0) { "[Filter: " + ($activeFilters -join ", ") + "]" } else { "[Filter: None]" }
        $sortPart = if ($sortDescs.Count -gt 0) { "[Sort: " + ($sortDescs -join " -> ") + "]" } else { "[Sort: Catalog ID]" }
        $lblStatus.Text = "Active Pipeline: $filterPart | $sortPart"
    }
    $lblStatus.ToolTip = $lblStatus.Text
}

function Refresh-GameList {
    $search = $txtSearch.Text.Trim()
    $index = Get-LibraryIndexCached
    $statusById = @{}
    foreach ($c in $allCatalog) {
        $statusById[[int]$c.id] = Check-GameLocation $c $index
    }

    $items = @($allCatalog)

    # 1. Console Filter
    switch ($script:consoleState) {
        1 { $items = $items | Where-Object { $_.platform -eq "PS1" } }
        2 { $items = $items | Where-Object { $_.platform -eq "PS2" } }
    }

    # 2. Graphics Filter
    switch ($script:graphicsState) {
        1 { $items = $items | Where-Object { $_.graphics -like "*High*" } }
        2 { $items = $items | Where-Object { $_.graphics -like "*Low*" } }
        3 { $items = $items | Where-Object { $_.graphics -like "*Retro*" } }
    }

    # 3. Status Filter (reuses precomputed statusById)
    if ($script:statusFilterState -eq 1) {
        $items = $items | Where-Object { $null -eq $statusById[[int]$_.id] }
    } elseif ($script:statusFilterState -eq 2) {
        $items = $items | Where-Object { $null -ne $statusById[[int]$_.id] }
    }

    # 4. Search Filter
    if (-not [string]::IsNullOrWhiteSpace($search)) {
        $items = $items | Where-Object {
            $_.title -like "*$search*" -or $_.genre -like "*$search*" -or $_.platform -like "*$search*"
        }
    }

    # 5. Coherent Multi-Tier Sorting with Deterministic ID Tie-Break
    $sortProps = @()
    $hasSizeSort = $script:sortPriority.Contains("Size")
    foreach ($col in $script:sortPriority) {
        if ($col -eq "Size") {
            $sortProps += @{ Expression = { [int]$_.SizeTier }; Descending = ($script:sizeSortState -eq 2) }
        } elseif ($col -eq "Year") {
            $sortProps += @{ Expression = { [int]$_.year }; Descending = ($script:yearSortState -eq 1) }
        } elseif ($col -eq "Genre") {
            $sortProps += @{ Expression = { $_.genre }; Descending = ($script:genreSortState -eq 2) }
        } elseif ($col -eq "Title") {
            $sortProps += @{ Expression = { $_.title }; Descending = ($script:titleSortState -eq 2) }
        }
    }
    if ($hasSizeSort) {
        $sortProps += @{ Expression = { [double]$_.SizeBytes }; Descending = ($script:sizeSortState -eq 2) }
    }
    $sortProps += @{ Expression = { [int]$_.id }; Descending = $false }
    $items = $items | Sort-Object -Property $sortProps

    $script:suppressCount = $true
    try {
        $displayedModels.Clear()
        foreach ($item in $items) {
            $loc = $statusById[[int]$item.id]
            $statusStr = if ($null -ne $loc) { "INSTALLED ($loc)" } else { "AVAILABLE" }

            $m = New-Object RetroGameItem
            $m.Id = "$($item.id)."
            $m.Platform = $item.platform
            $m.Title = $item.title
            $m.Year = "$($item.year)"
            $m.Genre = $item.genre
            $m.Graphics = $item.graphics
            $m.Size = $item.size
            $m.SizeBytes = $item.SizeBytes
            $m.SizeTier = [int]$item.SizeTier
            $m.Status = $statusStr
            $m.RawItem = $item
            $m.IsSelected = $script:selectedIds.Contains([int]$item.id)

            $m.add_PropertyChanged({
                param($sender, $e)
                if ($e.PropertyName -eq "IsSelected" -and $null -ne $sender.RawItem) {
                    Set-GameSelected ([int]$sender.RawItem.id) $sender.IsSelected
                    Update-SelectionCount
                }
            })

            $displayedModels.Add($m)
        }
    } finally {
        $script:suppressCount = $false
    }

    $lvGames.ItemsSource = $displayedModels
    $lblGameCount.Text = "$($displayedModels.Count) Games Listed"
    Update-SelectionCount
}

function Get-RowModelFromSource($originalSource) {
    $node = $originalSource
    while ($null -ne $node -and -not ($node -is [System.Windows.Controls.ListViewItem])) {
        if ($node -is [System.Windows.Media.Visual] -or $node -is [System.Windows.Media.Media3D.Visual3D]) {
            $node = [System.Windows.Media.VisualTreeHelper]::GetParent($node)
        } else {
            $node = [System.Windows.LogicalTreeHelper]::GetParent($node)
        }
    }
    if ($node -is [System.Windows.Controls.ListViewItem] -and $node.DataContext -is [RetroGameItem]) {
        return $node.DataContext
    }
    return $null
}

function Get-ContextTargets {
    $sel = @(Get-SelectedGames)
    if ($sel.Count -gt 0) { return $sel }
    if ($null -ne $script:contextModel) { return @($script:contextModel) }
    return @()
}

function Open-GameLocalLocation($item) {
    $entry = Resolve-GameEntry $item (Get-LibraryIndexCached)
    if ($null -ne $entry -and (Test-Path -LiteralPath $entry.FullPath)) {
        Start-Process explorer.exe -ArgumentList "/select,`"$($entry.FullPath)`""
        $lblStatus.Text = "Selected installed file for '$($item.title)' on $($entry.Slot)."
        return
    }
    $targetObj = if ($rbHDD.IsChecked) { $script:storageList[0] } else { $script:storageList[1] }
    $subDir = if ($item.platform -eq "PS1") { "PS1" } else { "PS2" }
    $destFolder = Join-Path $targetObj.Path $subDir
    if (-not (Test-Path -LiteralPath $destFolder)) {
        try { New-Item -ItemType Directory -Path $destFolder -Force | Out-Null } catch {}
    }
    if (Test-Path -LiteralPath $destFolder) { Invoke-Item -LiteralPath $destFolder }
    $lblStatus.Text = "Opened storage folder for '$($item.title)' on $($targetObj.Key)."
}

# --- Event: Frictionless Left-Click Multi-Select (No Ctrl Required) ---
$lvGames.Add_PreviewMouseLeftButtonDown({
    param($sender, $e)
    # Ignore double-clicks so MouseDoubleClick stays clean; let CheckBox toggle itself
    if ($e.ClickCount -ge 2) { return }
    $src = $e.OriginalSource
    while ($null -ne $src -and -not ($src -is [System.Windows.Controls.ListViewItem])) {
        if ($src -is [System.Windows.Controls.Primitives.ToggleButton]) { return }
        if ($src -is [System.Windows.Media.Visual] -or $src -is [System.Windows.Media.Media3D.Visual3D]) {
            $src = [System.Windows.Media.VisualTreeHelper]::GetParent($src)
        } else {
            $src = [System.Windows.LogicalTreeHelper]::GetParent($src)
        }
    }
    $model = Get-RowModelFromSource $e.OriginalSource
    if ($null -ne $model) {
        $model.IsSelected = -not $model.IsSelected
        $script:contextModel = $model
        $e.Handled = $true
    }
})

# --- Event: Mouse Right-Click to Select Item (Never Toggle Off) & Update Context Menu ---
$lvGames.Add_MouseRightButtonUp({
    param($sender, $e)
    $model = Get-RowModelFromSource $e.OriginalSource
    if ($null -ne $model) {
        $script:contextModel = $model
        if (-not $model.IsSelected) { $model.IsSelected = $true }
        $cnt = (Get-SelectedGames).Count
        if ($cnt -gt 1) {
            $cmOpenBrowser.Header = "Open $cnt Download Links in Browser"
            $cmOpenDetails.Header = "Open $cnt Archive.org Details Pages"
            $cmCopyUrl.Header     = "Copy $cnt Download URLs"
        } else {
            $cmOpenBrowser.Header = "Open Download Link in Browser"
            $cmOpenDetails.Header = "Open Archive.org Details Page"
            $cmCopyUrl.Header     = "Copy Download URL"
        }
    }
})

# --- Event: Mouse Double-Click to Open in Browser or File Explorer ---
$lvGames.Add_MouseDoubleClick({
    param($sender, $e)
    $model = Get-RowModelFromSource $e.OriginalSource
    if ($null -ne $model -and $null -ne $model.RawItem) {
        $item = $model.RawItem
        $loc = Check-GameLocation $item
        if ($null -ne $loc) {
            Open-GameLocalLocation $item
        } else {
            Open-UrlInBrowser $item.url
            $lblStatus.Text = "Opened download link for '$($item.title)' in browser."
        }
    }
})

# --- Context Menu Event Wiring (Batch-Aware) ---
$cmOpenBrowser.Add_Click({
    $targets = @(Get-ContextTargets)
    if ($targets.Count -eq 0) { return }
    if ($targets.Count -gt 5) {
        $confirm = [System.Windows.MessageBox]::Show("Open $($targets.Count) download tabs in your default browser?", "Confirm Multiple Tabs", "YesNo", "Question")
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }
    }
    foreach ($t in $targets) {
        if ($t.RawItem -and $t.RawItem.url) { Open-UrlInBrowser $t.RawItem.url }
    }
    $lblStatus.Text = "Opened $($targets.Count) download link(s) in browser."
})

$cmOpenDetails.Add_Click({
    $targets = @(Get-ContextTargets)
    if ($targets.Count -eq 0) { return }
    if ($targets.Count -gt 5) {
        $confirm = [System.Windows.MessageBox]::Show("Open $($targets.Count) Archive.org details pages in your default browser?", "Confirm Multiple Tabs", "YesNo", "Question")
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }
    }
    foreach ($t in $targets) {
        $item = $t.RawItem
        if ($item -and $item.url) {
            $detailsUrl = $item.url
            if ($detailsUrl -like "*archive.org/download/*") {
                $parts = $detailsUrl -replace "https://archive.org/download/", ""
                $itemId = $parts.Split('/')[0]
                $detailsUrl = "https://archive.org/details/$itemId"
            }
            Open-UrlInBrowser $detailsUrl
        }
    }
    $lblStatus.Text = "Opened $($targets.Count) Archive.org details page(s) in browser."
})

$cmCopyUrl.Add_Click({
    $targets = @(Get-ContextTargets)
    $urls = @($targets | ForEach-Object { if ($_.RawItem -and $_.RawItem.url) { $_.RawItem.url } })
    if ($urls.Count -gt 0) {
        try {
            [System.Windows.Clipboard]::SetText(($urls -join "`r`n"))
            $lblStatus.Text = "Copied $($urls.Count) download URL(s) to clipboard."
        } catch {
            $lblStatus.Text = "Failed to copy URL(s) to clipboard."
        }
    }
})

$cmOpenFolder.Add_Click({
    $target = if ($null -ne $script:contextModel) { $script:contextModel } else { (Get-ContextTargets | Select-Object -First 1) }
    if ($target -and $target.RawItem) {
        Open-GameLocalLocation $target.RawItem
    }
})

# --- Event: Column Headers (Pure ASCII Arrows: No Encoding Artifacts) ---

# 1. Reset all sorts to catalog ID order
$hdrNo.Add_Click({
    $script:titleSortState = 0
    $script:yearSortState = 0
    $script:sizeSortState = 0
    $script:genreSortState = 0
    $script:sortPriority.Clear()

    Update-HeaderLabels
    Update-PipelineStatus
    Refresh-GameList
})

# 2. Console Cycle (All -> PS1 -> PS2)
$hdrConsole.Add_Click({
    $script:consoleState = ($script:consoleState + 1) % 3
    Update-HeaderLabels
    Update-PipelineStatus
    Refresh-GameList
})

# 3. Title Sort Cycle (1 = A-Z -> 2 = Z-A -> 0 = Off -> 1 = A-Z)
$hdrTitle.Add_Click({
    if ($script:titleSortState -eq 1) {
        $script:titleSortState = 2
    } elseif ($script:titleSortState -eq 2) {
        $script:titleSortState = 0
    } else {
        $script:titleSortState = 1
    }

    if ($script:titleSortState -ne 0) {
        [void]$script:sortPriority.Remove("Title")
        $script:sortPriority.Insert(0, "Title")
    } else {
        [void]$script:sortPriority.Remove("Title")
    }

    Update-HeaderLabels
    Update-PipelineStatus
    Refresh-GameList
})

# 4. Release Year Sort Cycle (0 = Off -> 1 = Latest -> 2 = Oldest -> 0 = Off)
$hdrYear.Add_Click({
    $script:yearSortState = ($script:yearSortState + 1) % 3
    if ($script:yearSortState -ne 0) {
        [void]$script:sortPriority.Remove("Year")
        $script:sortPriority.Insert(0, "Year")
    } else {
        [void]$script:sortPriority.Remove("Year")
    }

    Update-HeaderLabels
    Update-PipelineStatus
    Refresh-GameList
})

# 5. Genre Sort Cycle (0 = Off -> 1 = A-Z -> 2 = Z-A -> 0 = Off)
$hdrGenre.Add_Click({
    $script:genreSortState = ($script:genreSortState + 1) % 3
    if ($script:genreSortState -ne 0) {
        [void]$script:sortPriority.Remove("Genre")
        $script:sortPriority.Insert(0, "Genre")
    } else {
        [void]$script:sortPriority.Remove("Genre")
    }

    Update-HeaderLabels
    Update-PipelineStatus
    Refresh-GameList
})

# 6. Graphics Filter Cycle (All -> High -> Low -> 2D)
$hdrGraphics.Add_Click({
    $script:graphicsState = ($script:graphicsState + 1) % 4
    Update-HeaderLabels
    Update-PipelineStatus
    Refresh-GameList
})

# 7. Size Sort Cycle (0 = Off -> 1 = Lowest -> 2 = Highest -> 0 = Off)
$hdrSize.Add_Click({
    $script:sizeSortState = ($script:sizeSortState + 1) % 3
    if ($script:sizeSortState -ne 0) {
        [void]$script:sortPriority.Remove("Size")
        $script:sortPriority.Insert(0, "Size")
    } else {
        [void]$script:sortPriority.Remove("Size")
    }

    Update-HeaderLabels
    Update-PipelineStatus
    Refresh-GameList
})

# 8. Status Filter Cycle (All -> Available -> Installed)
$hdrStatus.Add_Click({
    $script:statusFilterState = ($script:statusFilterState + 1) % 3
    Update-HeaderLabels
    Update-PipelineStatus
    Refresh-GameList
})

# --- Multi-Select Buttons (Operate on Visible Rows; Clear All Clears Hidden Too) ---
$btnSelectAll.Add_Click({
    $script:suppressCount = $true
    try { foreach ($m in $displayedModels) { $m.IsSelected = $true } } finally { $script:suppressCount = $false }
    Update-SelectionCount
    $hidden = [math]::Max(0, $script:selectedIds.Count - (Get-VisibleSelectedCount))
    if ($hidden -gt 0) { $lblStatus.Text = "Selected $($displayedModels.Count) visible rows ($hidden additional selections outside current filter)." }
})

$btnSelectNone.Add_Click({
    $script:suppressCount = $true
    try { foreach ($m in $displayedModels) { $m.IsSelected = $false } } finally { $script:suppressCount = $false }
    Update-SelectionCount
    if ($script:selectedIds.Count -gt 0) { $lblStatus.Text = "Cleared visible selections; $($script:selectedIds.Count) selections kept outside current filter (use Clear All to clear all)." }
})

$btnSelectInvert.Add_Click({
    $script:suppressCount = $true
    try { foreach ($m in $displayedModels) { $m.IsSelected = -not $m.IsSelected } } finally { $script:suppressCount = $false }
    Update-SelectionCount
    $hidden = [math]::Max(0, $script:selectedIds.Count - (Get-VisibleSelectedCount))
    if ($hidden -gt 0) { $lblStatus.Text = "Inverted $($displayedModels.Count) visible rows; $hidden selections kept outside current filter." }
})

$btnClearAllSel.Add_Click({
    $script:suppressCount = $true
    try {
        $script:selectedIds.Clear()
        foreach ($m in $displayedModels) { $m.IsSelected = $false }
    } finally { $script:suppressCount = $false }
    Update-SelectionCount
    $lblStatus.Text = "Cleared all selections."
})

# --- Dedicated Reset All Filters and Sorts Button ---
function Reset-AllFiltersAndSorts {
    $script:suppressTextChanged = $true
    try {
        $script:consoleState = 0
        $script:graphicsState = 0
        $script:statusFilterState = 0
        $txtSearch.Text = ""
    } finally {
        $script:suppressTextChanged = $false
    }

    $script:yearSortState = 0
    $script:sizeSortState = 0
    $script:genreSortState = 0
    $script:titleSortState = 1

    $script:sortPriority.Clear()
    $script:sortPriority.Add("Title")

    Update-HeaderLabels
    Update-PipelineStatus
    Refresh-GameList
}

$btnResetFilters.Add_Click({
    Reset-AllFiltersAndSorts
})

# --- Help Button [?] Dialog ---
$btnHelp.Add_Click({
    $helpLines = @(
        "=== MULTI-SELECT & BROWSER CONTROLS ===",
        "- Click checkboxes or click any row to multi-select games without holding Ctrl.",
        "- Use 'All', 'None', or 'Invert' buttons to quickly manage selections.",
        "- In-App Download: Click 'Download Selected Games' to download directly through the app.",
        "- Browser Manual Download: Click 'Open in Browser' to open download links in your default web browser (recommended if Archive.org blocks scripts or asks for login).",
        "- Double-Click: Double-click any game row to open its download link in browser (or open its folder if installed).",
        "- Right-Click: Right-click any row to view actions: Open in Browser, Open Archive Details, Copy URL, or Open Folder.",
        "",
        "=== MOST-RECENTLY-CHANGED MULTI-SORTING ===",
        "- Whichever sort header you click immediately becomes Priority [#1].",
        "- Previously active sorts shift to [#2], [#3], etc. and remain active as tie-breakers.",
        "- Cycle: Click a sort header until it returns to default ('v') to turn that sort off.",
        "- Size-Tier Cohesion: When Size is [#1] and Year/Genre is [#2], games group into size tiers (<500MB, 500MB-1GB, 1GB-2GB, 2GB-3.5GB, >3.5GB) and order by your secondary criteria.",
        "- Reset Filters: Click 'Reset Filters' in Row 1 to instantly restore default view (Title A-Z).",
        "- Catalog ID Reset: Click 'No. v' to sort strictly by original catalog ID.",
        "",
        "=== STORAGE & BIOS ===",
        "- Toggle between HDD and SSD storage targets at the top.",
        "- Double-click either storage pill to browse and select a custom target folder in Windows Explorer.",
        "- Custom storage paths are automatically saved to storage_config.json.",
        "- Click 'Open BIOS Folder' to open and place emulator BIOS files."
    )
    $helpMsg = $helpLines -join "`n"
    [System.Windows.MessageBox]::Show($helpMsg, "Controls & Tips", "OK", "Information")
})

$script:searchTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:searchTimer.Interval = [TimeSpan]::FromMilliseconds(180)
$script:searchTimer.Add_Tick({
    $script:searchTimer.Stop()
    Update-PipelineStatus
    Refresh-GameList
})

$txtSearch.Add_TextChanged({
    if ($script:suppressTextChanged) { return }
    $script:searchTimer.Stop()
    $script:searchTimer.Start()
})

$btnBios.Add_Click({
    $targetObj = if ($rbHDD.IsChecked) { $script:storageList[0] } else { $script:storageList[1] }
    $p = Join-Path $targetObj.Path "BIOS"
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    Invoke-Item $p
})

# --- Open Selected Games in Web Browser ---
$btnOpenBrowser.Add_Click({
    $selectedModels = Get-SelectedGames
    if ($selectedModels.Count -eq 0) {
        if ($lvGames.SelectedItem -is [RetroGameItem]) {
            $selectedModels = @($lvGames.SelectedItem)
        }
    }

    if ($selectedModels.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Please click checkboxes or a row to select games to open in your browser!", "No Games Selected", "OK", "Information")
        return
    }

    if ($selectedModels.Count -gt 5) {
        $confirm = [System.Windows.MessageBox]::Show("You selected $($selectedModels.Count) games. Are you sure you want to open $($selectedModels.Count) browser tabs at once?", "Confirm Multiple Tabs", "YesNo", "Question")
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) {
            return
        }
    }

    foreach ($m in $selectedModels) {
        $item = $m.RawItem
        if ($item -and $item.url) {
            Open-UrlInBrowser $item.url
        }
    }
    $lblStatus.Text = "Opened $($selectedModels.Count) download link(s) in your default web browser."
})

$script:abortBatch    = $false
$script:isDownloading = $false

$btnStop.Add_Click({
    $script:abortBatch = $true
    $btnStop.IsEnabled = $false
    $lblProgress.Text = "Cancelling after current chunk..."
})

$window.Add_Closing({
    param($sender, $e)
    if ($script:isDownloading) {
        $res = [System.Windows.MessageBox]::Show("A download batch is currently running. Stop downloads and close?", "Download In Progress", "YesNo", "Warning")
        if ($res -ne [System.Windows.MessageBoxResult]::Yes) {
            $e.Cancel = $true
            return
        }
        $script:abortBatch = $true
    }
})

# --- Batch / Single Download ---
$btnDownload.Add_Click({
    $selectedModels = Get-SelectedGames
    if ($selectedModels.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Please click checkboxes or rows to select games for download!", "No Games Selected", "OK", "Information") | Out-Null
        return
    }
    $hiddenSel = [math]::Max(0, $selectedModels.Count - (Get-VisibleSelectedCount))
    if ($hiddenSel -gt 0) {
        $c = [System.Windows.MessageBox]::Show("Download $($selectedModels.Count) games ($hiddenSel not visible under the current filter)?", "Confirm Selection Scope", "YesNo", "Question")
        if ($c -ne [System.Windows.MessageBoxResult]::Yes) { return }
    }

    $targetObj = if ($rbHDD.IsChecked) { $script:storageList[0] } else { $script:storageList[1] }

    # Pre-flight drive availability, writability, and free-space check (B-09, B-10)
    $drive = Get-PSDrive $targetObj.Drive -ErrorAction SilentlyContinue
    if (-not $drive -or $null -eq $drive.Free) {
        [System.Windows.MessageBox]::Show("Drive $($targetObj.Drive): is not available. Double-click a storage pill to choose another folder.", "Storage Unavailable", "OK", "Warning") | Out-Null
        return
    }
    if (-not (Test-FolderWritable $targetObj.Path)) {
        [System.Windows.MessageBox]::Show("Target folder is not writable:`n$($targetObj.Path)`n`nDouble-click the storage pill to choose a writable folder.", "Storage Not Writable", "OK", "Warning") | Out-Null
        return
    }
    $index = Get-LibraryIndexCached
    $pendingModels = @($selectedModels | Where-Object { $null -eq (Check-GameLocation $_.RawItem $index) })
    $needBytes = 0.0
    foreach ($pm in $pendingModels) { $needBytes += [double]$pm.SizeBytes }
    if ($needBytes -gt ($drive.Free * 0.95)) {
        $msg = "Selected uninstalled games need {0:N1} GB, but only {1:N1} GB is free on {2} ({3}:).`n`nContinue anyway?" -f ($needBytes / 1GB), ($drive.Free / 1GB), $targetObj.Name, $targetObj.Drive
        if ([System.Windows.MessageBox]::Show($msg, "Insufficient Disk Space", "YesNo", "Warning") -ne [System.Windows.MessageBoxResult]::Yes) { return }
    }

    Enable-ModernTls

    $script:abortBatch    = $false
    $script:isDownloading = $true
    $btnDownload.IsEnabled     = $false
    $btnOpenBrowser.IsEnabled  = $false
    $rbHDD.IsEnabled           = $false
    $rbSSD.IsEnabled           = $false
    $btnResetFilters.IsEnabled = $false
    $pnlProgress.Visibility    = [System.Windows.Visibility]::Visible
    $btnStop.Visibility        = [System.Windows.Visibility]::Visible
    $btnStop.IsEnabled         = $true

    $totalQueue     = $selectedModels.Count
    $completedCount = 0
    $skippedCount   = 0
    $cancelled      = $false
    $failedItems    = @()

    try {
        for ($idx = 0; $idx -lt $totalQueue; $idx++) {
            if ($script:abortBatch) { $cancelled = $true; break }

            $model    = $selectedModels[$idx]
            $item     = $model.RawItem
            $queueNum = $idx + 1

            $existingLoc = Check-GameLocation $item $index
            if ($null -ne $existingLoc) {
                $skippedCount++
                $lblStatus.Text = "[$queueNum/$totalQueue] Skipped '$($item.title)' (Already installed on $existingLoc)."
                $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
                continue
            }

            $subDir     = if ($item.platform -eq "PS1") { "PS1" } else { "PS2" }
            $destFolder = Join-Path $targetObj.Path $subDir
            if (-not (Ensure-DestFolder $destFolder)) {
                $failedItems += @{ Item = $item; Error = "Cannot create destination folder '$destFolder'." }
                continue
            }
            $outFile  = Join-Path $destFolder $item.fileName
            $partFile = "$outFile.part"

            $lblStatus.Text = "[$queueNum/$totalQueue] Downloading '$($item.title)' to $($targetObj.Name) ($($targetObj.Drive):)..."
            $lblProgress.Text = "[$queueNum/$totalQueue] Connecting..."
            $pbDownload.IsIndeterminate = $true
            $pbDownload.Value = 0
            $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)

            $sw     = [System.Diagnostics.Stopwatch]::StartNew()
            $lastUI = 0
            $fs     = $null
            $stream = $null
            $wc     = $null

            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
                $wc.Headers.Add("Accept-Encoding", "identity")
                $stream = $wc.OpenRead($item.url)

                $totalBytes = [int64]0
                $lenHeader  = $wc.ResponseHeaders["Content-Length"]
                if ($lenHeader -and [int64]::TryParse($lenHeader, [ref]$totalBytes) -and $totalBytes -gt 0) {
                    $pbDownload.IsIndeterminate = $false
                } else {
                    $totalBytes = 0
                    $pbDownload.IsIndeterminate = $true
                }

                $fs         = [System.IO.File]::Create($partFile)
                $buffer     = New-Object byte[] 65536
                $downloaded = [int64]0

                while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    if ($script:abortBatch) { $cancelled = $true; break }
                    $fs.Write($buffer, 0, $read)
                    $downloaded += $read

                    if ($sw.ElapsedMilliseconds - $lastUI -gt 150) {
                        $lastUI = $sw.ElapsedMilliseconds
                        $speedMBs = if ($sw.Elapsed.TotalSeconds -gt 0) { [math]::Round(($downloaded / 1MB) / $sw.Elapsed.TotalSeconds, 1) } else { 0 }
                        if ($totalBytes -gt 0) {
                            $pct = [math]::Min(100, [math]::Round(($downloaded / $totalBytes) * 100, 1))
                            $pbDownload.IsIndeterminate = $false
                            $pbDownload.Value = $pct
                            $lblProgress.Text = "[$queueNum/$totalQueue] $pct% ({0:N1} MB / {1:N1} MB)" -f ($downloaded / 1MB), ($totalBytes / 1MB)
                        } else {
                            $pbDownload.IsIndeterminate = $true
                            $lblProgress.Text = "[$queueNum/$totalQueue] {0:N1} MB downloaded" -f ($downloaded / 1MB)
                        }
                        $lblSpeed.Text = "$speedMBs MB/s"
                        $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
                    }
                }

                $fs.Close(); $fs = $null
                $stream.Close(); $stream = $null
                $wc.Dispose(); $wc = $null

                if ($cancelled) {
                    if (Test-Path -LiteralPath $partFile) { Remove-Item -LiteralPath $partFile -Force -ErrorAction SilentlyContinue }
                    break
                }

                if (Test-Path -LiteralPath $outFile) { Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue }
                Move-Item -LiteralPath $partFile -Destination $outFile -Force

                if ($outFile.EndsWith(".zip", [System.StringComparison]::OrdinalIgnoreCase)) {
                    $pbDownload.IsIndeterminate = $true
                    $lblProgress.Text = "[$queueNum/$totalQueue] Extracting archive (this may take a moment)..."
                    $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
                    Expand-GameArchive $outFile $destFolder
                    Remove-Item -LiteralPath $outFile -Force
                }

                $completedCount++
                $pbDownload.IsIndeterminate = $false
                $pbDownload.Value = 100
            } catch {
                if ($null -ne $fs) { $fs.Close(); $fs = $null }
                if ($null -ne $stream) { $stream.Close(); $stream = $null }
                if ($null -ne $wc) { $wc.Dispose(); $wc = $null }
                if (Test-Path -LiteralPath $partFile) { Remove-Item -LiteralPath $partFile -Force -ErrorAction SilentlyContinue }

                $errSummary = $_.Exception.Message
                Write-AppLog "Download failed for '$($item.title)': $errSummary" "ERROR"
                $failedItems += @{ Item = $item; Error = $errSummary }
                $lblStatus.Text = "ERROR on '$($item.title)': $errSummary"
                $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
            }
        }
    } finally {
        $script:isDownloading      = $false
        $btnDownload.IsEnabled     = $true
        $btnOpenBrowser.IsEnabled  = $true
        $rbHDD.IsEnabled           = $true
        $rbSSD.IsEnabled           = $true
        $btnResetFilters.IsEnabled = $true
        $btnStop.Visibility        = [System.Windows.Visibility]::Collapsed
        $pbDownload.IsIndeterminate = $false
    }

    $lblSpeed.Text = ""
    $failedCount   = $failedItems.Count
    if ($cancelled) {
        $pbDownload.Value = 0
        $lblProgress.Text = "Cancelled"
        $lblStatus.Text   = "Batch cancelled: $completedCount downloaded, $skippedCount skipped, $failedCount failed."
    } else {
        $pbDownload.Value = 100
        $lblProgress.Text = "Batch Completed"
        $lblStatus.Text   = "Finished batch: $completedCount downloaded, $skippedCount duplicates skipped, $failedCount failed/blocked."
        try { [System.Console]::Beep(1000, 200) } catch {}
    }

    Reset-LibraryIndexCache
    Refresh-StorageLabels
    Refresh-GameList

    if ($cancelled) {
        [System.Windows.MessageBox]::Show("Download batch cancelled.`nDownloaded: $completedCount`nSkipped: $skippedCount`nFailed: $failedCount", "Download Cancelled", "OK", "Information") | Out-Null
    } elseif ($failedCount -eq 0) {
        [System.Windows.MessageBox]::Show("Batch finished!`nDownloaded: $completedCount`nSkipped (Already installed): $skippedCount", "Download Finished", "OK", "Information") | Out-Null
    } else {
        $failedNames = ($failedItems | ForEach-Object { "- $($_.Item.title) ($($_.Error))" }) -join "`n"
        if ($failedNames.Length -gt 500) { $failedNames = $failedNames.Substring(0, 497) + "..." }

        $msg = "Batch finished with issues:`n`nDownloaded: $completedCount`nSkipped (Already installed): $skippedCount`nBlocked / Failed: $failedCount`n`nDetails:`n$failedNames`n`nArchive.org may have blocked automated scripting for the failed games (requires browser verification or login).`n`nWould you like to open the failed download link(s) in your browser to download manually?"
        $res = [System.Windows.MessageBox]::Show($msg, "Downloads Blocked - Open in Browser?", "YesNo", "Warning")
        if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
            foreach ($f in $failedItems) {
                Open-UrlInBrowser $f.Item.url
            }
        }
    }
})

# --- Fluid Title Column Layout (Zero Horizontal Overflow) ---
function Update-ColumnLayout {
    if ($lvGames.ActualWidth -le 0) { return }
    $fixed = 40 + 44 + 105 + 70 + 170 + 115 + 100 + 135
    $avail = $lvGames.ActualWidth - 26
    $lvGames.View.Columns[3].Width = [math]::Max(220, ($avail - $fixed))
}
$lvGames.Add_SizeChanged({ Update-ColumnLayout })

# --- Keyboard Shortcuts (Ctrl+A, Esc, F5) ---
$window.Add_KeyDown({
    param($sender, $e)
    $mods = [System.Windows.Input.Keyboard]::Modifiers
    if ($e.Key -eq [System.Windows.Input.Key]::Escape -and $txtSearch.IsKeyboardFocusWithin) {
        $txtSearch.Text = ""
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::F5) {
        Reset-LibraryIndexCache
        Refresh-StorageLabels
        Refresh-GameList
        $lblStatus.Text = "Library rescanned."
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::A -and ($mods -band [System.Windows.Input.ModifierKeys]::Control) -and -not $txtSearch.IsKeyboardFocusWithin) {
        $script:suppressCount = $true
        try { foreach ($m in $displayedModels) { $m.IsSelected = $true } } finally { $script:suppressCount = $false }
        Update-SelectionCount
        $e.Handled = $true
    }
})

# Initial Bind
Refresh-StorageLabels
Update-HeaderLabels
Update-PipelineStatus
Refresh-GameList

# Launch Window
$window.ShowDialog() | Out-Null
