# ==============================
# CONFIGURATION
# ==============================

$InstanceId = "YOUR_CONNECT_INSTANCE_ID"
$QuickConnectFile = "quick_connect.txt"
$OutputFile = "step7.txt"

# ==============================
# VALIDATE INPUT FILE
# ==============================

if (-not (Test-Path $QuickConnectFile)) {
    Write-Host "Quick Connect file not found: $QuickConnectFile" -ForegroundColor Red
    return
}

$QuickConnectIds = Get-Content $QuickConnectFile | Where-Object { $_.Trim() -ne "" }

if (-not $QuickConnectIds) {
    Write-Host "Quick Connect file is empty." -ForegroundColor Red
    return
}

Write-Host "Loaded $($QuickConnectIds.Count) Quick Connect ID(s)."

# Clear output file if it exists
if (Test-Path $OutputFile) {
    Remove-Item $OutputFile
}

# ==============================
# PROCESS EACH QUICK CONNECT
# ==============================

foreach ($QCId in $QuickConnectIds) {

    Write-Host "Describing Quick Connect: $QCId"

    try {

        $Response = aws connect describe-quick-connect `
            --instance-id $InstanceId `
            --quick-connect-id $QCId `
            --output json

        # Add separator for readability
        Add-Content -Path $OutputFile -Value "==============================="
        Add-Content -Path $OutputFile -Value "QuickConnectId: $QCId"
        Add-Content -Path $OutputFile -Value "==============================="
        Add-Content -Path $OutputFile -Value $Response
        Add-Content -Path $OutputFile -Value "`n"

    }
    catch {
        Add-Content -Path $OutputFile -Value "ERROR retrieving QuickConnectId: $QCId"
        Add-Content -Path $OutputFile -Value $_
        Add-Content -Path $OutputFile -Value "`n"
    }
}

Write-Host "Completed."
Write-Host "Results written to $OutputFile" -ForegroundColor Cyan
