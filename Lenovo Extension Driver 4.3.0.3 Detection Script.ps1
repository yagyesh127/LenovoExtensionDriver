# --------------------------------------------------
# Lenovo Extension Driver 4.3.0.3 Detection Script
# For Intune Proactive Remediation (Detection)
# --------------------------------------------------

$TargetVersion = [version]"4.3.0.3"
$DriverFound   = $false

# --------------------------------------------------
# Helper function: safely extract field from text block
# --------------------------------------------------
function Get-FieldValue {
    param (
        [string]$Text,
        [string]$Pattern
    )

    $match = $Text | Select-String -Pattern $Pattern

    if ($match -and $match.Matches.Count -gt 0) {
        return $match.Matches[0].Groups[1].Value.Trim()
    }
    else {
        return $null
    }
}

# --------------------------------------------------
# Step 1: Get full driver list using pnputil
# (Best source for extension drivers)
# --------------------------------------------------
$rawOutput = pnputil /enum-drivers

# Convert to single string for parsing
$driverText = $rawOutput | Out-String

# Split into individual driver blocks
$blocks = $driverText -split "Published Name\s*:\s*"

# --------------------------------------------------
# Step 2: Process each driver block safely
# --------------------------------------------------
foreach ($block in $blocks) {

    # Skip empty entries
    if ([string]::IsNullOrWhiteSpace($block)) { continue }

    # Extract fields safely
    $provider = Get-FieldValue $block "Provider Name\s*:\s*(.+)"
    $version  = Get-FieldValue $block "Driver Version\s*:\s*(.+)"
    $original = Get-FieldValue $block "Original Name\s*:\s*(.+)"

    # Skip if critical data missing
    if (-not $provider -or -not $version) { continue }

    # Extract only numeric version (pnputil includes date)
    # Example: "06/15/2023 4.3.0.3" → "4.3.0.3"
    $cleanVersion = ($version -split "\s+")[-1]

    # --------------------------------------------------
    # Step 3: Match Lenovo Extension Driver
    # --------------------------------------------------
    if ($provider -match "Lenovo" -and (
            ($original -and $original -match "Extension") -or
            ($block -match "Extension")   # fallback for inconsistent naming
        )) {

        try {
            if ([version]$cleanVersion -eq $TargetVersion) {
                $DriverFound = $true

                Write-Output "Match Found:"
                Write-Output "Provider : $provider"
                Write-Output "Version  : $cleanVersion"
                Write-Output "INF Name : $original"

                break
            }
        }
        catch {
            Write-Output "Version parsing failed for: $version"
        }
    }
}

# --------------------------------------------------
# Step 4: Check reboot status
# --------------------------------------------------
$RebootPending = 
    (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -or
    (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired")

# --------------------------------------------------
# Step 5: Final Intune Detection Result
# --------------------------------------------------

if ($DriverFound -and -not $RebootPending) {

    Write-Output "STATUS: WITHOUT ISSUES"
    Write-Output "Lenovo Extension Driver 4.3.0.3 installed successfully. No reboot pending."

    exit 0   # ✅ Intune → Without Issues

}
elseif ($DriverFound -and $RebootPending) {

    Write-Output "STATUS: WITH ISSUES"
    Write-Output "Driver installed but reboot is pending."

    exit 1   # ⚠️ Intune → With Issues

}
else {

    Write-Output "STATUS: WITH ISSUES"
    Write-Output "Driver not found or incorrect version."

    exit 1   # ⚠️ Intune → With Issues

}