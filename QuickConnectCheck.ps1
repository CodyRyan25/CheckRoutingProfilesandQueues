# ===============================
# CONFIGURATION
# ===============================

# Your Amazon Connect Instance ID
$InstanceId = "YOUR_INSTANCE_ID"

# Files
$queueFilterFile = "./filteredQueueList.txt"
$outputCsv       = "./QueueQuickConnects.csv"

# ===============================
# VALIDATE INPUT FILE
# ===============================

if (!(Test-Path $queueFilterFile)) {
    Write-Host "ERROR: filteredQueueList.txt not found!"
    exit
}

$queueIds = Get-Content $queueFilterFile

Write-Host "Loaded $($queueIds.Count) queues..."

# ===============================
# GET QUEUE NAMES
# ===============================

$queueLookup = @{}

foreach ($queueId in $queueIds) {

    $queueJson = aws connect describe-queue `
        --instance-id $InstanceId `
        --queue-id $queueId `
        --output json

    $queue = $queueJson | ConvertFrom-Json

    $queueLookup[$queueId] = $queue.Queue.Name
}

# ===============================
# GET QUICK CONNECTS
# ===============================

Write-Host "Retrieving quick connects..."

$quickConnectIds = aws connect list-quick-connects `
    --instance-id $InstanceId `
    --query "QuickConnectSummaryList[].Id" `
    --output text

$quickConnectList = $quickConnectIds -split "`t"

# ===============================
# MATCH QUICK CONNECTS TO QUEUES
# ===============================

$results = @()

foreach ($quickConnectId in $quickConnectList) {

    Write-Host "Checking QuickConnect: $quickConnectId"

    $qcJson = aws connect describe-quick-connect `
        --instance-id $InstanceId `
        --quick-connect-id $quickConnectId `
        --output json

    $qc = $qcJson | ConvertFrom-Json

    # Only Queue-type QuickConnects have QueueId
    if ($qc.QuickConnect.QuickConnectConfig.QueueConfig.QueueId) {

        $queueId = $qc.QuickConnect.QuickConnectConfig.QueueConfig.QueueId

        if ($queueIds -contains $queueId) {

            $results += [PSCustomObject]@{
                QueueName        = $queueLookup[$queueId]
                QueueId          = $queueId
                QuickConnectName = $qc.QuickConnect.Name
            }

        }
    }
}

# ===============================
# EXPORT CSV
# ===============================

$results | Export-Csv -Path $outputCsv -NoTypeInformation

Write-Host "Completed."
Write-Host "Results saved to $outputCsv"
