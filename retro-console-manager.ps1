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

Add-Type -TypeDefinition $csharpModel -ErrorAction SilentlyContinue

# --- Storage & Path Configuration (Relative & Portable) ---
$scriptDir = if ($PSScriptRoot) {
    $PSScriptRoot
} elseif ($MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $cur = (Get-Location).Path
    if (Test-Path (Join-Path $cur "games_catalog.json")) {
        $cur
    } else {
        "C:\Users\kazir\Documents\Agentic Harness\Retro Console Manager"
    }
}
$jsonFile = Join-Path $scriptDir "games_catalog.json"
$configFile = Join-Path $scriptDir "storage_config.json"

function Load-StorageConfig {
    $defaultLeft = if (Test-Path "E:\") { "E:\Cracked\Console_Games" } else { Join-Path $env:USERPROFILE "Retro_Games\Primary_Storage" }
    $defaultRight = "C:\Retro_Games\Console_Games"

    $cfgLeft = $defaultLeft
    $cfgRight = $defaultRight

    if (Test-Path $configFile) {
        try {
            $loaded = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($loaded.LeftPath -and (-not [string]::IsNullOrWhiteSpace($loaded.LeftPath))) {
                $cfgLeft = $loaded.LeftPath
            }
            if ($loaded.RightPath -and (-not [string]::IsNullOrWhiteSpace($loaded.RightPath))) {
                $cfgRight = $loaded.RightPath
            }
        } catch {}
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
    } catch {}
}

function Ensure-StorageFolders {
    foreach ($s in $script:storageList) {
        try {
            $root = [System.IO.Path]::GetPathRoot($s.Path)
            if ($root -and $root.Length -ge 1) {
                $s.Drive = $root.Substring(0,1).ToUpper()
            }
        } catch {}
        foreach ($sub in @("PS1", "PS2", "BIOS")) {
            try {
                $p = Join-Path $s.Path $sub
                if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
            } catch {}
        }
    }
}

Load-StorageConfig
Ensure-StorageFolders

function Get-Catalog {
    if (Test-Path $jsonFile) {
        $raw = Get-Content $jsonFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($item in $raw) {
            $sz = $item.size.ToUpper()
            $num = [double]($sz -replace '[^\d\.]', '')
            $bytes = if ($sz -like "*GB*") { $num * 1024 * 1024 * 1024 } else { $num * 1024 * 1024 }
            $item | Add-Member -NotePropertyName "SizeBytes" -NotePropertyValue $bytes -Force

            # SizeTier for multi-tier coherent sorting:
            # Tier 1 (Compact): < 500 MB
            # Tier 2 (Medium-Small): 500 MB - 1 GB
            # Tier 3 (Medium): 1 GB - 2 GB
            # Tier 4 (Large): 2 GB - 3.5 GB
            # Tier 5 (Extra Large): >= 3.5 GB
            $tier = if ($bytes -lt (500 * 1024 * 1024)) {
                1
            } elseif ($bytes -lt (1024 * 1024 * 1024)) {
                2
            } elseif ($bytes -lt (2 * 1024 * 1024 * 1024)) {
                3
            } elseif ($bytes -lt (3.5 * 1024 * 1024 * 1024)) {
                4
            } else {
                5
            }
            $item | Add-Member -NotePropertyName "SizeTier" -NotePropertyValue $tier -Force

            if (-not $item.year) {
                $item | Add-Member -NotePropertyName "year" -NotePropertyValue 2004 -Force
            }
            if (-not $item.graphics) {
                $item | Add-Member -NotePropertyName "graphics" -NotePropertyValue "High (Realistic)" -Force
            }
        }
        return $raw
    }
    return @()
}

function Check-GameLocation($item) {
    $subDir = if ($item.platform -eq "PS1") { "PS1" } else { "PS2" }
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($item.fileName)
    $shortName = $item.title.Split('(')[0].Split(':')[0].Trim()

    foreach ($s in $script:storageList) {
        $targetFolder = Join-Path $s.Path $subDir
        if (Test-Path (Join-Path $targetFolder $item.fileName)) { return $s.Key }
        if (Test-Path (Join-Path $targetFolder "$baseName.chd")) { return $s.Key }
        if (Test-Path (Join-Path $targetFolder "$baseName.iso")) { return $s.Key }
        if (Test-Path (Join-Path $targetFolder "$baseName.bin")) { return $s.Key }
        
        $found = Get-ChildItem -Path $targetFolder -ErrorAction SilentlyContinue | Where-Object { 
            $_.BaseName -like "*$shortName*" -or $_.Name -like "*$shortName*" 
        }
        if ($null -ne $found) { return $s.Key }
    }
    return $null
}

function Get-FreeSpaceGB($driveLetter) {
    try {
        $d = Get-PSDrive $driveLetter -ErrorAction SilentlyContinue
        if ($d) { return [math]::Round($d.Free / 1GB, 1) }
    } catch {}
    return 0
}

# --- XAML User Interface Layout ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Retro Console Game Manager (PS1 &amp; PS2)" Height="780" Width="1180"
        MinHeight="600" MinWidth="860"
        WindowStartupLocation="CenterScreen" Background="#0A0F1D" Foreground="#F1F5F9"
        FontFamily="Segoe UI" FontSize="13">
    <Window.Resources>
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
            <Setter Property="Margin" Value="6,0,6,0"/>
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

        <!-- Custom ListViewItem: Pure Dark Contrast with Mouse-Over and Selection Highlight -->
        <Style TargetType="ListViewItem">
            <Setter Property="IsSelected" Value="{Binding IsSelected, Mode=TwoWay}"/>
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
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="RowBorder" Property="Background" Value="#1E293B"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="RowBorder" Property="Background" Value="#1D4ED8"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <MultiTrigger>
                                <MultiTrigger.Conditions>
                                    <Condition Property="IsSelected" Value="True"/>
                                    <Condition Property="IsMouseOver" Value="True"/>
                                </MultiTrigger.Conditions>
                                <Setter TargetName="RowBorder" Property="Background" Value="#2563EB"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </MultiTrigger>
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

        <!-- Checkbox Style -->
        <Style TargetType="CheckBox">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
            <Setter Property="HorizontalAlignment" Value="Center"/>
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
                    <RadioButton Name="rbHDD" GroupName="StorageTarget" Content="Hard Disk Drive (E:) [Loading...]" Style="{StaticResource LargeStoragePill}" IsChecked="True"/>
                </StackPanel>

                <!-- Column 1 (Middle): App Title (Centered) -->
                <TextBlock Grid.Column="1" Text="RETRO CONSOLE MANAGER" FontWeight="Bold" FontSize="16" Foreground="#38BDF8" 
                           VerticalAlignment="Center" HorizontalAlignment="Center"/>

                <!-- Column 2 (Right): Solid State Drive Storage Pill -->
                <StackPanel Grid.Column="2" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                    <RadioButton Name="rbSSD" GroupName="StorageTarget" Content="Solid State Drive (C:) [Loading...]" Style="{StaticResource LargeStoragePill}" Margin="0"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- ROW 1: SEARCH, MULTI-SELECT, RESET, HELP & DOWNLOAD ACTION BAR -->
        <Border Grid.Row="1" Background="#111827" CornerRadius="6" Padding="14,8" Margin="0,0,0,8" BorderBrush="#1F2937" BorderThickness="1">
            <DockPanel LastChildFill="False">
                <!-- Left: Search Box -->
                <StackPanel Orientation="Horizontal" DockPanel.Dock="Left" VerticalAlignment="Center" Margin="0,0,20,0">
                    <TextBlock Text="Search:" VerticalAlignment="Center" Foreground="#94A3B8" Margin="0,0,8,0" FontWeight="SemiBold"/>
                    <TextBox Name="txtSearch" Width="200" Background="#1E293B" Foreground="#F8FAFC" BorderBrush="#334155" 
                             CaretBrush="#38BDF8" Padding="8,4" VerticalAlignment="Center"
                             ToolTip="Type keyword to filter games by title, genre, or system"/>
                </StackPanel>

                <!-- Center: Multi-Selection Controls, Counter, Help Button & Reset Filters -->
                <StackPanel Orientation="Horizontal" DockPanel.Dock="Left" VerticalAlignment="Center">
                    <TextBlock Text="Select:" Foreground="#94A3B8" VerticalAlignment="Center" Margin="0,0,8,0" FontWeight="SemiBold"/>
                    <Button Name="btnSelectAll" Content="All" Margin="0,0,5,0" Padding="10,4"/>
                    <Button Name="btnSelectNone" Content="None" Margin="0,0,5,0" Padding="10,4"/>
                    <Button Name="btnSelectInvert" Content="Invert" Margin="0,0,12,0" Padding="10,4"/>
                    <TextBlock Name="lblSelectionCount" Text="0 selected" Foreground="#38BDF8" FontWeight="Bold" VerticalAlignment="Center" Margin="0,0,8,0"/>
                    <Button Name="btnHelp" Content="?" Width="26" Height="26" Padding="0" Margin="0,0,8,0" FontWeight="Bold" 
                            Foreground="#38BDF8" Background="#1E293B" BorderBrush="#334155" BorderThickness="1" 
                            VerticalAlignment="Center" ToolTip="Click for Controls &amp; Filter Help"/>
                    <Button Name="btnResetFilters" Content="Reset Filters" Margin="0,0,14,0" Padding="10,4" 
                            Background="#1E293B" Foreground="#F8FAFC" BorderBrush="#334155" 
                            ToolTip="Reset all filters, search text, and sorting back to default"/>
                </StackPanel>

                <!-- Right: Download Selected Games Button + Open BIOS Folder -->
                <Button Name="btnDownload" Content="Download Selected Games" DockPanel.Dock="Right" 
                        Background="#10B981" Foreground="#0F172A" FontWeight="Bold" FontSize="13" Padding="20,7" Cursor="Hand"/>
                <Button Name="btnBios" Content="Open BIOS Folder" DockPanel.Dock="Right" Margin="0,0,10,0" Padding="14,6" Background="#1E293B" VerticalAlignment="Center"/>
            </DockPanel>
        </Border>

        <!-- ROW 2: GAMES TABLE WITH CHECKBOXES & CLICKABLE PURE-ASCII HEADERS -->
        <ListView Name="lvGames" Grid.Row="2" Background="#090E1A" Foreground="#E2E8F0" BorderBrush="#1F2937" BorderThickness="1"
                  SelectionMode="Multiple"
                  VirtualizingStackPanel.IsVirtualizing="False"
                  ScrollViewer.HorizontalScrollBarVisibility="Auto"
                  ScrollViewer.VerticalScrollBarVisibility="Auto">
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
                    <GridViewColumn Width="46" DisplayMemberBinding="{Binding Id}">
                        <GridViewColumn.Header>
                            <Button Name="hdrNo" Content="No. v" Style="{StaticResource HeaderBtn}" ToolTip="Reset all sorts to Catalog ID order"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>

                    <!-- Column 2: Console (Cycles ALL / PS1 / PS2) -->
                    <GridViewColumn Width="110" DisplayMemberBinding="{Binding Platform}">
                        <GridViewColumn.Header>
                            <Button Name="hdrConsole" Content="Console: All [v]" Style="{StaticResource HeaderBtn}" Foreground="#38BDF8" ToolTip="Click to Cycle: All -> PS1 -> PS2"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>

                    <!-- Column 3: Title (Cycles A-Z / Z-A / Off) -->
                    <GridViewColumn Width="310" DisplayMemberBinding="{Binding Title}">
                        <GridViewColumn.Header>
                            <Button Name="hdrTitle" Content="Title (A-Z) ^ [#1]" Style="{StaticResource HeaderBtn}" Foreground="#38BDF8" ToolTip="Click to cycle Title sort (Most recently clicked becomes [#1])"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>

                    <!-- Column 4: Release Year -->
                    <GridViewColumn Width="85" DisplayMemberBinding="{Binding Year}">
                        <GridViewColumn.Header>
                            <Button Name="hdrYear" Content="Year v" Style="{StaticResource HeaderBtn}" ToolTip="Click to cycle Year sort (Most recently clicked becomes [#1])"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>

                    <!-- Column 5: Genre -->
                    <GridViewColumn Width="210" DisplayMemberBinding="{Binding Genre}">
                        <GridViewColumn.Header>
                            <Button Name="hdrGenre" Content="Genre v" Style="{StaticResource HeaderBtn}" ToolTip="Click to cycle Genre sort (Most recently clicked becomes [#1])"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>

                    <!-- Column 6: Graphics (High / Low / 2D / All) -->
                    <GridViewColumn Width="140" DisplayMemberBinding="{Binding Graphics}">
                        <GridViewColumn.Header>
                            <Button Name="hdrGraphics" Content="Graphics: All [v]" Style="{StaticResource HeaderBtn}" Foreground="#38BDF8" ToolTip="Click to Cycle: All -> High (Realistic) -> Low (Stylized) -> Retro (2D)"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>

                    <!-- Column 7: Download Size -->
                    <GridViewColumn Width="120" DisplayMemberBinding="{Binding Size}">
                        <GridViewColumn.Header>
                            <Button Name="hdrSize" Content="Size v" Style="{StaticResource HeaderBtn}" ToolTip="Click to cycle Size sort (Most recently clicked becomes [#1])"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>

                    <!-- Column 8: Status (Cycles All / Available / Installed) -->
                    <GridViewColumn Width="150" DisplayMemberBinding="{Binding Status}">
                        <GridViewColumn.Header>
                            <Button Name="hdrStatus" Content="Status: All [v]" Style="{StaticResource HeaderBtn}" Foreground="#38BDF8" ToolTip="Click to Cycle: All -> Available Only -> Installed Only"/>
                        </GridViewColumn.Header>
                    </GridViewColumn>
                </GridView>
            </ListView.View>
        </ListView>

        <!-- ROW 3: PROGRESS BAR -->
        <Border Grid.Row="3" Margin="0,8,0,6">
            <StackPanel>
                <ProgressBar Name="pbDownload" Height="8" Background="#1E293B" Foreground="#38BDF8" BorderThickness="0" Value="0" Maximum="100"/>
                <DockPanel LastChildFill="False" Margin="0,4,0,0">
                    <TextBlock Name="lblProgress" Text="Ready" Foreground="#94A3B8" FontSize="12" DockPanel.Dock="Left"/>
                    <TextBlock Name="lblSpeed" Text="" Foreground="#FCD34D" FontSize="12" FontWeight="SemiBold" DockPanel.Dock="Right"/>
                </DockPanel>
            </StackPanel>
        </Border>

        <!-- ROW 4: FOOTER STATUS -->
        <Border Grid.Row="4" Background="#060A14" CornerRadius="4" Padding="10,6" BorderBrush="#1F2937" BorderThickness="1">
            <DockPanel LastChildFill="False">
                <TextBlock Name="lblStatus" Text="Ready. Default (Title A-Z)" 
                           Foreground="#94A3B8" FontSize="12" DockPanel.Dock="Left"/>
                <TextBlock Name="lblGameCount" Text="58 Games Loaded" Foreground="#38BDF8" FontWeight="SemiBold" FontSize="12" DockPanel.Dock="Right"/>
            </DockPanel>
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
$lblSelectionCount = $window.FindName("lblSelectionCount")
$btnHelp           = $window.FindName("btnHelp")
$btnResetFilters   = $window.FindName("btnResetFilters")
$btnDownload       = $window.FindName("btnDownload")
$lvGames           = $window.FindName("lvGames")
$pbDownload        = $window.FindName("pbDownload")
$lblProgress       = $window.FindName("lblProgress")
$lblSpeed          = $window.FindName("lblSpeed")
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
$brushEmerald  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")

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

function Refresh-StorageLabels {
    $drive0 = $script:storageList[0].Drive
    $drive1 = $script:storageList[1].Drive
    $h = Get-FreeSpaceGB $drive0
    $s = Get-FreeSpaceGB $drive1

    $leaf0 = Split-Path $script:storageList[0].Path -Leaf
    if ($script:storageList[0].Path -eq "E:\Cracked\Console_Games") {
        $rbHDD.Content = "Hard Disk Drive ($($drive0):) [$h GB Free]"
    } else {
        $rbHDD.Content = "Hard Disk Drive ($($drive0): $leaf0) [$h GB Free]"
    }

    $leaf1 = Split-Path $script:storageList[1].Path -Leaf
    if ($script:storageList[1].Path -eq "C:\Retro_Games\Console_Games") {
        $rbSSD.Content = "Solid State Drive ($($drive1):) [$s GB Free]"
    } else {
        $rbSSD.Content = "Solid State Drive ($($drive1): $leaf1) [$s GB Free]"
    }

    $rbHDD.ToolTip = "Active Path: $($script:storageList[0].Path)`nDouble-click to browse and select a custom folder"
    $rbSSD.ToolTip = "Active Path: $($script:storageList[1].Path)`nDouble-click to browse and select a custom folder"
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
                Refresh-StorageLabels
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

function Get-SelectedGames {
    return @($displayedModels | Where-Object { $_.IsSelected -eq $true })
}

function Update-SelectionCount {
    $sel = Get-SelectedGames
    $count = $sel.Count
    $lblSelectionCount.Text = "$count selected"
    if ($count -eq 0) {
        $btnDownload.Content = "Download Selected Games"
        $btnDownload.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
    } elseif ($count -eq 1) {
        $btnDownload.Content = "Download 1 Game"
        $btnDownload.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#059669")
    } else {
        $btnDownload.Content = "Download $count Games (Batch)"
        $btnDownload.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#059669")
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
}

function Refresh-GameList {
    $search = $txtSearch.Text.Trim()
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

    # 3. Status Filter
    if ($script:statusFilterState -eq 1) {
        $items = $items | Where-Object { $null -eq (Check-GameLocation $_) }
    } elseif ($script:statusFilterState -eq 2) {
        $items = $items | Where-Object { $null -ne (Check-GameLocation $_) }
    }

    # 4. Search Filter
    if (-not [string]::IsNullOrWhiteSpace($search)) {
        $items = $items | Where-Object { 
            $_.title -like "*$search*" -or $_.genre -like "*$search*" -or $_.platform -like "*$search*"
        }
    }

    # 5. Coherent Multi-Tier Sorting
    $sortProps = @()
    $sizeIdx = $script:sortPriority.IndexOf("Size")
    $hasSecondaryAfterSize = $false
    if ($sizeIdx -ge 0) {
        for ($k = $sizeIdx + 1; $k -lt $script:sortPriority.Count; $k++) {
            if ($script:sortPriority[$k] -eq "Year" -or $script:sortPriority[$k] -eq "Genre") {
                $hasSecondaryAfterSize = $true
                break
            }
        }
    }

    foreach ($col in $script:sortPriority) {
        if ($col -eq "Size") {
            if ($hasSecondaryAfterSize) {
                $sortProps += @{ Expression = { [int]$_.SizeTier }; Descending = ($script:sizeSortState -eq 2) }
            } else {
                $sortProps += @{ Expression = { [double]$_.SizeBytes }; Descending = ($script:sizeSortState -eq 2) }
            }
        } elseif ($col -eq "Year") {
            $sortProps += @{ Expression = { [int]$_.year }; Descending = ($script:yearSortState -eq 1) }
        } elseif ($col -eq "Genre") {
            $sortProps += @{ Expression = { $_.genre }; Descending = ($script:genreSortState -eq 2) }
        } elseif ($col -eq "Title") {
            $sortProps += @{ Expression = { $_.title }; Descending = ($script:titleSortState -eq 2) }
        }
    }

    if ($hasSecondaryAfterSize) {
        $sortProps += @{ Expression = { [double]$_.SizeBytes }; Descending = ($script:sizeSortState -eq 2) }
    }

    if ($sortProps.Count -gt 0) {
        $items = $items | Sort-Object -Property $sortProps
    } else {
        $items = $items | Sort-Object { [int]$_.id }
    }

    # Preserve selections if already checked
    $selectedIds = New-Object System.Collections.Generic.HashSet[int]
    foreach ($m in $displayedModels) {
        if ($m.IsSelected -and $null -ne $m.RawItem) {
            [void]$selectedIds.Add([int]$m.RawItem.id)
        }
    }

    $displayedModels.Clear()
    foreach ($item in $items) {
        $loc = Check-GameLocation $item
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
        $m.IsSelected = $selectedIds.Contains([int]$item.id)

        # Subscribe to property change for live count updates
        $m.add_PropertyChanged({
            param($sender, $e)
            if ($e.PropertyName -eq "IsSelected") {
                Update-SelectionCount
            }
        })

        $displayedModels.Add($m)
    }

    $lvGames.ItemsSource = $displayedModels
    $lblGameCount.Text = "$($displayedModels.Count) Games Listed"
    Update-SelectionCount
}

# --- Event: Mouse Right-Click to Toggle Selection on Any Row ---
$lvGames.Add_MouseRightButtonUp({
    param($sender, $e)
    $hit = [System.Windows.Media.VisualTreeHelper]::GetParent($e.OriginalSource)
    while ($null -ne $hit -and -not ($hit -is [System.Windows.Controls.ListViewItem])) {
        $hit = [System.Windows.Media.VisualTreeHelper]::GetParent($hit)
    }
    if ($null -ne $hit -and ($hit -is [System.Windows.Controls.ListViewItem])) {
        $model = $hit.DataContext
        if ($model -is [RetroGameItem]) {
            $model.IsSelected = -not $model.IsSelected
        }
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

# --- Multi-Select Buttons ---
$btnSelectAll.Add_Click({
    foreach ($m in $displayedModels) { $m.IsSelected = $true }
    Update-SelectionCount
})

$btnSelectNone.Add_Click({
    foreach ($m in $displayedModels) { $m.IsSelected = $false }
    Update-SelectionCount
})

$btnSelectInvert.Add_Click({
    foreach ($m in $displayedModels) { $m.IsSelected = -not $m.IsSelected }
    Update-SelectionCount
})

# --- Dedicated Reset All Filters and Sorts Button ---
function Reset-AllFiltersAndSorts {
    $script:consoleState = 0
    $script:graphicsState = 0
    $script:statusFilterState = 0
    $txtSearch.Text = ""

    $script:yearSortState = 0
    $script:sizeSortState = 0
    $script:genreSortState = 0
    $script:titleSortState = 1

    $script:sortPriority.Clear()
    $script:sortPriority.Add("Title")

    Update-HeaderLabels
    Refresh-GameList
    $lblStatus.Text = "All filters and sorting reset to default."
}

$btnResetFilters.Add_Click({
    Reset-AllFiltersAndSorts
})

# --- Help Button [?] Dialog ---
$btnHelp.Add_Click({
    $helpLines = @(
        "=== MULTI-SELECT CONTROLS ===",
        "- Click checkboxes, left-click, or right-click any row to multi-select games without holding Ctrl.",
        "- Use 'All', 'None', or 'Invert' buttons to quickly manage selections.",
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

$txtSearch.Add_TextChanged({
    Update-PipelineStatus
    Refresh-GameList
})

$btnBios.Add_Click({
    $targetObj = if ($rbHDD.IsChecked) { $script:storageList[0] } else { $script:storageList[1] }
    $p = Join-Path $targetObj.Path "BIOS"
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    Invoke-Item $p
})

# --- Batch / Single Download ---
$btnDownload.Add_Click({
    $selectedModels = Get-SelectedGames
    if ($selectedModels.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Please click checkboxes or rows to select games for download!", "No Games Selected", "OK", "Information")
        return
    }

    $targetObj = if ($rbHDD.IsChecked) { $script:storageList[0] } else { $script:storageList[1] }
    $btnDownload.IsEnabled = $false
    $totalQueue = $selectedModels.Count
    $completedCount = 0
    $skippedCount = 0

    for ($idx = 0; $idx -lt $totalQueue; $idx++) {
        $model = $selectedModels[$idx]
        $item = $model.RawItem
        $queueNum = $idx + 1

        $existingLoc = Check-GameLocation $item
        if ($null -ne $existingLoc) {
            $skippedCount++
            $lblStatus.Text = "[$queueNum/$totalQueue] Skipped '$($item.title)' (Already installed on $existingLoc)."
            continue
        }

        $subDir = if ($item.platform -eq "PS1") { "PS1" } else { "PS2" }
        $destFolder = Join-Path $targetObj.Path $subDir
        $outFile = Join-Path $destFolder $item.fileName

        $lblStatus.Text = "[$queueNum/$totalQueue] Downloading '$($item.title)' to $($targetObj.Name)..."
        $lblProgress.Text = "Connecting..."
        $pbDownload.Value = 0

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $lastUI = 0

        try {
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
            $stream = $wc.OpenRead($item.url)
            $totalBytes = [int64]$wc.ResponseHeaders["Content-Length"]
            $fs = [System.IO.File]::Create($outFile)
            $buffer = New-Object byte[] 65536
            $downloaded = 0

            while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $fs.Write($buffer, 0, $read)
                $downloaded += $read

                if ($sw.ElapsedMilliseconds - $lastUI -gt 150) {
                    $lastUI = $sw.ElapsedMilliseconds
                    $pct = if ($totalBytes -gt 0) { [math]::Min(100, [math]::Round(($downloaded / $totalBytes) * 100, 1)) } else { 0 }
                    $speedMBs = if ($sw.Elapsed.TotalSeconds -gt 0) { [math]::Round(($downloaded / 1MB) / $sw.Elapsed.TotalSeconds, 1) } else { 0 }
                    
                    $pbDownload.Value = $pct
                    $lblProgress.Text = "[$queueNum/$totalQueue] $pct% ({0:N1} MB / {1:N1} MB)" -f ($downloaded / 1MB), ($totalBytes / 1MB)
                    $lblSpeed.Text = "$speedMBs MB/s"
                    
                    $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
                }
            }

            $fs.Close()
            $stream.Close()
            $wc.Dispose()

            if ($outFile.EndsWith(".zip")) {
                $lblProgress.Text = "[$queueNum/$totalQueue] Extracting game archive..."
                Expand-Archive -Path $outFile -DestinationPath $destFolder -Force
                Remove-Item $outFile -Force
            }

            $completedCount++
            $pbDownload.Value = 100
        } catch {
            if ($null -ne $fs) { $fs.Close() }
            if (Test-Path $outFile) { Remove-Item $outFile -Force -ErrorAction SilentlyContinue }
            $lblStatus.Text = "ERROR on '$($item.title)': $($_.Exception.Message)"
        }
    }

    $btnDownload.IsEnabled = $true
    $pbDownload.Value = 100
    $lblProgress.Text = "Batch Completed"
    $lblSpeed.Text = ""
    $lblStatus.Text = "Finished batch: $completedCount downloaded, $skippedCount duplicates skipped."
    try { [System.Console]::Beep(1000, 200) } catch {}
    
    Refresh-StorageLabels
    Refresh-GameList
    [System.Windows.MessageBox]::Show("Batch finished!`nDownloaded: $completedCount`nSkipped (Already installed): $skippedCount", "Download Finished", "OK", "Information")
})

# Initial Bind
Refresh-StorageLabels
Update-HeaderLabels
Update-PipelineStatus
Refresh-GameList

# Launch Window
$window.ShowDialog() | Out-Null
