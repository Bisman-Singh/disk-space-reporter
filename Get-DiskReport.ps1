<#
.SYNOPSIS
    Generates a disk space utilization report with color-coded output and optional HTML export.

.DESCRIPTION
    Get-DiskReport.ps1 lists all disk drives with used/free/total space,
    provides color-coded console output, and can generate an HTML report
    with visual bar charts using inline CSS.

.PARAMETER WarningThreshold
    Percentage of used space that triggers a warning (yellow). Default: 50.

.PARAMETER CriticalThreshold
    Percentage of used space that triggers a critical alert (red). Default: 80.

.PARAMETER OutputHTML
    Path to generate an HTML report file.

.PARAMETER Help
    Display help information.

.EXAMPLE
    .\Get-DiskReport.ps1

.EXAMPLE
    .\Get-DiskReport.ps1 -WarningThreshold 60 -CriticalThreshold 85

.EXAMPLE
    .\Get-DiskReport.ps1 -OutputHTML .\disk-report.html
#>

[CmdletBinding()]
param(
    [int]$WarningThreshold = 50,
    [int]$CriticalThreshold = 80,
    [string]$OutputHTML = "",
    [switch]$Help
)

# ─── Help ────────────────────────────────────────────────────────────────────────
if ($Help) {
    @"
Get-DiskReport.ps1 - Disk Space Utilization Reporter

USAGE:
    .\Get-DiskReport.ps1 [-WarningThreshold <pct>] [-CriticalThreshold <pct>] [-OutputHTML <path>] [-Help]

PARAMETERS:
    -WarningThreshold   Used% threshold for warning (yellow). Default: 50
    -CriticalThreshold  Used% threshold for critical (red). Default: 80
    -OutputHTML         Generate HTML report at specified path
    -Help               Show this help message

COLOR CODING:
    Green   - Used space below warning threshold (healthy)
    Yellow  - Used space between warning and critical thresholds
    Red     - Used space above critical threshold

EXAMPLES:
    .\Get-DiskReport.ps1
    .\Get-DiskReport.ps1 -WarningThreshold 60 -CriticalThreshold 85
    .\Get-DiskReport.ps1 -OutputHTML .\disk-report.html
"@
    exit 0
}

# ─── Validate thresholds ────────────────────────────────────────────────────────
if ($WarningThreshold -ge $CriticalThreshold) {
    Write-Error "WarningThreshold ($WarningThreshold) must be less than CriticalThreshold ($CriticalThreshold)."
    exit 1
}

# ─── Data collection ────────────────────────────────────────────────────────────

function Get-DiskData {
    <#
    .SYNOPSIS
        Collects disk utilization data across platforms.
    #>
    $disks = @()

    try {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            # Windows: use CIM
            $volumes = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop

            foreach ($vol in $volumes) {
                if ($vol.Size -gt 0) {
                    $usedBytes = $vol.Size - $vol.FreeSpace
                    $usedPct = [math]::Round(($usedBytes / $vol.Size) * 100, 1)
                    $freePct = [math]::Round(100 - $usedPct, 1)

                    $disks += [PSCustomObject]@{
                        Drive     = $vol.DeviceID
                        Label     = if ($vol.VolumeName) { $vol.VolumeName } else { "(No Label)" }
                        FileSystem = $vol.FileSystem
                        TotalGB   = [math]::Round($vol.Size / 1GB, 2)
                        UsedGB    = [math]::Round($usedBytes / 1GB, 2)
                        FreeGB    = [math]::Round($vol.FreeSpace / 1GB, 2)
                        UsedPct   = $usedPct
                        FreePct   = $freePct
                    }
                }
            }
        }
        else {
            # Linux/macOS: use df
            $dfOutput = df -k 2>/dev/null | Select-Object -Skip 1

            foreach ($line in $dfOutput) {
                $parts = $line -split '\s+'
                if ($parts.Count -ge 6 -and $parts[1] -match '^\d+$') {
                    $totalKB = [long]$parts[1]
                    $usedKB = [long]$parts[2]
                    $availKB = [long]$parts[3]

                    if ($totalKB -gt 0) {
                        $usedPct = [math]::Round(($usedKB / $totalKB) * 100, 1)
                        $freePct = [math]::Round(100 - $usedPct, 1)

                        $disks += [PSCustomObject]@{
                            Drive      = $parts[0]
                            Label      = $parts[5]
                            FileSystem = "N/A"
                            TotalGB    = [math]::Round($totalKB / 1MB, 2)
                            UsedGB     = [math]::Round($usedKB / 1MB, 2)
                            FreeGB     = [math]::Round($availKB / 1MB, 2)
                            UsedPct    = $usedPct
                            FreePct    = $freePct
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Error collecting disk data: $_"
    }

    return $disks
}

# ─── Collect data ───────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Disk Space Reporter" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Warning threshold:  >= ${WarningThreshold}% used" -ForegroundColor Yellow
Write-Host "Critical threshold: >= ${CriticalThreshold}% used" -ForegroundColor Red
Write-Host ""

$diskData = Get-DiskData

if ($diskData.Count -eq 0) {
    Write-Warning "No disk data collected."
    exit 1
}

# ─── Console output ─────────────────────────────────────────────────────────────
$headerFormat = "{0,-15} {1,-15} {2,10} {3,10} {4,10} {5,8} {6,-8}"
$header = $headerFormat -f "Drive", "Label", "Total(GB)", "Used(GB)", "Free(GB)", "Used%", "Status"
$separator = "-" * 80

Write-Host $header -ForegroundColor White
Write-Host $separator -ForegroundColor Gray

foreach ($disk in $diskData) {
    $status = "OK"
    $color = "Green"

    if ($disk.UsedPct -ge $CriticalThreshold) {
        $status = "CRITICAL"
        $color = "Red"
    }
    elseif ($disk.UsedPct -ge $WarningThreshold) {
        $status = "WARNING"
        $color = "Yellow"
    }

    $line = $headerFormat -f $disk.Drive, $disk.Label, $disk.TotalGB, $disk.UsedGB, $disk.FreeGB, "$($disk.UsedPct)%", $status
    Write-Host $line -ForegroundColor $color

    # Draw a simple bar chart in console
    $barWidth = 40
    $filledWidth = [math]::Round(($disk.UsedPct / 100) * $barWidth)
    $emptyWidth = $barWidth - $filledWidth
    $bar = "[" + ("#" * $filledWidth) + ("-" * $emptyWidth) + "]"
    Write-Host "                $bar $($disk.UsedPct)%" -ForegroundColor $color
}

Write-Host ""

# ─── Summary ─────────────────────────────────────────────────────────────────────
$totalSpace = ($diskData | Measure-Object -Property TotalGB -Sum).Sum
$totalUsed = ($diskData | Measure-Object -Property UsedGB -Sum).Sum
$totalFree = ($diskData | Measure-Object -Property FreeGB -Sum).Sum
$overallPct = if ($totalSpace -gt 0) { [math]::Round(($totalUsed / $totalSpace) * 100, 1) } else { 0 }

Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Total drives:     $($diskData.Count)"
Write-Host "  Total space:      $([math]::Round($totalSpace, 2)) GB"
Write-Host "  Total used:       $([math]::Round($totalUsed, 2)) GB ($overallPct%)"
Write-Host "  Total free:       $([math]::Round($totalFree, 2)) GB"

$criticalCount = ($diskData | Where-Object { $_.UsedPct -ge $CriticalThreshold }).Count
$warningCount = ($diskData | Where-Object { $_.UsedPct -ge $WarningThreshold -and $_.UsedPct -lt $CriticalThreshold }).Count

if ($criticalCount -gt 0) {
    Write-Host "  Critical drives:  $criticalCount" -ForegroundColor Red
}
if ($warningCount -gt 0) {
    Write-Host "  Warning drives:   $warningCount" -ForegroundColor Yellow
}

Write-Host ""

# ─── HTML report ─────────────────────────────────────────────────────────────────
if (-not [string]::IsNullOrWhiteSpace($OutputHTML)) {
    try {
        $rows = ""
        foreach ($disk in $diskData) {
            $barColor = "#27ae60"  # green
            if ($disk.UsedPct -ge $CriticalThreshold) {
                $barColor = "#e74c3c"  # red
            }
            elseif ($disk.UsedPct -ge $WarningThreshold) {
                $barColor = "#f39c12"  # yellow/orange
            }

            $statusText = "OK"
            if ($disk.UsedPct -ge $CriticalThreshold) { $statusText = "CRITICAL" }
            elseif ($disk.UsedPct -ge $WarningThreshold) { $statusText = "WARNING" }

            $rows += @"

            <tr>
                <td>$($disk.Drive)</td>
                <td>$($disk.Label)</td>
                <td>$($disk.TotalGB) GB</td>
                <td>$($disk.UsedGB) GB</td>
                <td>$($disk.FreeGB) GB</td>
                <td>
                    <div class="bar-container">
                        <div class="bar-fill" style="width: $($disk.UsedPct)%; background: $barColor;">
                            $($disk.UsedPct)%
                        </div>
                    </div>
                </td>
                <td style="color: $barColor; font-weight: bold;">$statusText</td>
            </tr>
"@
        }

        $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Disk Space Report</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 20px;
            background: #f5f5f5;
            color: #333;
        }
        .container {
            max-width: 1100px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        .meta {
            color: #888;
            font-size: 0.9em;
            margin-bottom: 20px;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 20px 0;
        }
        th {
            background: #2c3e50;
            color: white;
            padding: 12px 15px;
            text-align: left;
        }
        td {
            padding: 10px 15px;
            border-bottom: 1px solid #ddd;
        }
        tr:nth-child(even) { background: #f9f9f9; }
        tr:hover { background: #e8f4fd; }
        .bar-container {
            background: #ecf0f1;
            border-radius: 4px;
            overflow: hidden;
            height: 24px;
            min-width: 200px;
        }
        .bar-fill {
            height: 100%;
            border-radius: 4px;
            color: white;
            font-size: 12px;
            font-weight: bold;
            line-height: 24px;
            text-align: center;
            min-width: 35px;
            transition: width 0.3s ease;
        }
        .summary {
            background: #f8f9fa;
            padding: 15px 20px;
            border-radius: 6px;
            border-left: 4px solid #3498db;
            margin-top: 20px;
        }
        .summary h3 { margin-top: 0; color: #2c3e50; }
        .summary p { margin: 5px 0; }
        .legend {
            display: flex;
            gap: 20px;
            margin: 10px 0 20px 0;
        }
        .legend-item {
            display: flex;
            align-items: center;
            gap: 5px;
            font-size: 0.9em;
        }
        .legend-dot {
            width: 12px;
            height: 12px;
            border-radius: 50%;
        }
    </style>
</head>
<body>
<div class="container">
    <h1>Disk Space Report</h1>
    <p class="meta">Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Host: $(hostname)</p>

    <div class="legend">
        <div class="legend-item">
            <div class="legend-dot" style="background: #27ae60;"></div>
            <span>Healthy (&lt;${WarningThreshold}%)</span>
        </div>
        <div class="legend-item">
            <div class="legend-dot" style="background: #f39c12;"></div>
            <span>Warning (${WarningThreshold}-${CriticalThreshold}%)</span>
        </div>
        <div class="legend-item">
            <div class="legend-dot" style="background: #e74c3c;"></div>
            <span>Critical (&gt;${CriticalThreshold}%)</span>
        </div>
    </div>

    <table>
        <tr>
            <th>Drive</th>
            <th>Label</th>
            <th>Total</th>
            <th>Used</th>
            <th>Free</th>
            <th>Usage</th>
            <th>Status</th>
        </tr>
$rows
    </table>

    <div class="summary">
        <h3>Summary</h3>
        <p><strong>Total drives:</strong> $($diskData.Count)</p>
        <p><strong>Total space:</strong> $([math]::Round($totalSpace, 2)) GB</p>
        <p><strong>Total used:</strong> $([math]::Round($totalUsed, 2)) GB ($overallPct%)</p>
        <p><strong>Total free:</strong> $([math]::Round($totalFree, 2)) GB</p>
    </div>
</div>
</body>
</html>
"@

        $htmlContent | Out-File -FilePath $OutputHTML -Encoding utf8 -Force
        Write-Host "HTML report saved to: $OutputHTML" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to generate HTML report: $_"
        exit 1
    }
}

Write-Host "Done." -ForegroundColor Green
