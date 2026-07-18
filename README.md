# Disk Space Reporter

A PowerShell script that generates disk space utilization reports with color-coded output and optional HTML reports featuring visual bar charts.

## Features

- Lists all drives with total, used, and free space
- Color-coded console output: green (healthy), yellow (warning), red (critical)
- ASCII bar charts in console output
- HTML report generation with CSS-styled bar charts
- Configurable warning and critical thresholds
- Summary with total space across all drives
- Cross-platform support (Windows, macOS, Linux via PowerShell Core)

## Requirements

- PowerShell 5.1+ (Windows) or PowerShell 7+ (cross-platform)

## Usage

```powershell
# Default report (console output)
.\Get-DiskReport.ps1

# Custom thresholds
.\Get-DiskReport.ps1 -WarningThreshold 60 -CriticalThreshold 85

# Generate HTML report
.\Get-DiskReport.ps1 -OutputHTML .\disk-report.html

# Custom thresholds with HTML
.\Get-DiskReport.ps1 -WarningThreshold 40 -CriticalThreshold 75 -OutputHTML report.html

# Show help
.\Get-DiskReport.ps1 -Help
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `-WarningThreshold` | Used% threshold for warning (default: 50) |
| `-CriticalThreshold` | Used% threshold for critical (default: 80) |
| `-OutputHTML` | Path to generate HTML report |
| `-Help` | Show help information |

## Sample Console Output

```
Disk Space Reporter
===================
Timestamp: 2026-04-18 10:00:00
Warning threshold:  >= 50% used
Critical threshold: >= 80% used

Drive           Label            Total(GB)   Used(GB)   Free(GB)  Used%  Status
--------------------------------------------------------------------------------
C:              System              476.94     356.64     120.30  74.8%  WARNING
                [##############################----------] 74.8%
D:              Data                931.51     251.31     680.20  27.0%  OK
                [###########-----------------------------] 27.0%
E:              Backup              232.88     209.59      23.29  90.0%  CRITICAL
                [####################################----] 90.0%

Summary:
  Total drives:     3
  Total space:      1641.33 GB
  Total used:       817.54 GB (49.8%)
  Total free:       823.79 GB
  Critical drives:  1
  Warning drives:   1
```



<sub><sup>Originally developed and tested locally during learning. Later organized and pushed to GitHub for portfolio visibility.</sup></sub>
