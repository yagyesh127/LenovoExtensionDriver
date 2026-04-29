# --------------------------------------------------
# Remediation Script: Reboot Notification
# For Intune Proactive Remediations
# --------------------------------------------------

# --------------------------------------------------
# Step 1: Check if reboot is actually required
# --------------------------------------------------
$RebootPending = 
    (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -or
    (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired")

if (-not $RebootPending) {
    Write-Output "No reboot pending. Nothing to remediate."
    exit 0
}

# --------------------------------------------------
# Step 2: Check if a user is logged in
# --------------------------------------------------
$LoggedOnUser = (Get-CimInstance Win32_ComputerSystem).UserName

if (-not $LoggedOnUser) {
    Write-Output "Reboot pending but no user logged in."
    exit 0
}

# --------------------------------------------------
# Step 3: Send reboot notification to user
# (msg.exe works from SYSTEM context)
# --------------------------------------------------

$message = @"
Your device requires a restart to complete important updates.

Please save your work and restart your device as soon as possible.

If not restarted, your system may automatically restart later.
"@

try {
    msg.exe * /time:300 $message
    Write-Output "Reboot notification sent to user: $LoggedOnUser"
}
catch {
    Write-Output "Failed to send reboot message: $_"
    exit 1
}

# --------------------------------------------------
# Step 4: (Optional) Gentle escalation log
# --------------------------------------------------
Write-Output "Remediation completed: User notified for reboot."

exit 0