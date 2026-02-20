# ===============================
# CONFIGURATION
# ===============================

# Your Amazon Connect Instance ID
$InstanceId = "YOUR_INSTANCE_ID"

# Files
$quickConnectFile = "./filteredQuickConnects.txt"
$outputCsv        = "./QuickConnectQueueMapping.csv"

# ===============================
# VALIDATE INPUT FILE
# ===============================

if (!(Test-Path $quickConnectFile)) {
    Write-Host "ERROR: filteredQuickConnects.txt not found!"
    exit
}

$quickConnectIds = Get-Content $quickConnectFile

Write-Host "Loaded $($quickConnectIds.Count) quick connects..."

# ===============================
# DESCRIBE QUICK CONNECTS
# ===============================

$results = @()

foreach ($quickConnectId in $quickConnectIds) {

    Write-Host "Describing QuickConnect: $quickConnectId"

    $qcJson = aws connect describe-quick-connect `
        --instance-id $InstanceId `
        --quick-connect-id $quickConnectId `
        --output json

    $qc = $qcJson | ConvertFrom-Json

    $queueId = $qc.QuickConnect.QuickConnectConfig.QueueConfig.QueueId

    $results += [PSCustomObject]@{
        QuickConnectId   = $quickConnectId
        QuickConnectName = $qc.QuickConnect.Name
        QueueId          = $queueId
    }
}

# ===============================
# EXPORT CSV
# ===============================

$results | Export-Csv -Path $outputCsv -NoTypeInformation

Write-Host "Completed."
Write-Host "Results saved to $outputCsv"