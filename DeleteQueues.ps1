# ===============================
# CONFIGURATION
# ===============================

$InstanceId = "YOUR_INSTANCE_ID"

$queueFile = "./filteredQueueList.txt"

# ===============================
# VALIDATE INPUT FILE
# ===============================

if (!(Test-Path $queueFile)) {
    Write-Host "ERROR: filteredQueueList.txt not found!"
    exit 1
}

$queueIds = Get-Content $queueFile

Write-Host ""
Write-Host "Starting SAFE Queue Deletion..."
Write-Host "Total Queues: $($queueIds.Count)"
Write-Host ""

# ===============================
# LOAD ROUTING PROFILE REFERENCES
# ===============================

Write-Host "Loading Routing Profile references..."

$routingProfileIds = aws connect list-routing-profiles `
    --instance-id $InstanceId `
    --query "RoutingProfileSummaryList[].Id" `
    --output text

$routingProfileList = $routingProfileIds -split "`t"

$routingProfileQueueRefs = @{}

foreach ($rpId in $routingProfileList) {

    $rpQueuesJson = aws connect list-routing-profile-queues `
        --instance-id $InstanceId `
        --routing-profile-id $rpId `
        --output json

    $rpQueues = $rpQueuesJson | ConvertFrom-Json

    foreach ($q in $rpQueues.RoutingProfileQueueConfigSummaryList) {
        $routingProfileQueueRefs[$q.QueueId] = $true
    }
}

Write-Host "Routing Profile references loaded."
Write-Host ""

# ===============================
# LOAD QUICK CONNECT REFERENCES
# ===============================

Write-Host "Loading Quick Connect references..."

$quickConnectIds = aws connect list-quick-connects `
    --instance-id $InstanceId `
    --query "QuickConnectSummaryList[].Id" `
    --output text

$quickConnectList = $quickConnectIds -split "`t"

$quickConnectQueueRefs = @{}

foreach ($qcId in $quickConnectList) {

    $qcJson = aws connect describe-quick-connect `
        --instance-id $InstanceId `
        --quick-connect-id $qcId `
        --output json

    $qc = $qcJson | ConvertFrom-Json

    $queueId = $qc.QuickConnect.QuickConnectConfig.QueueConfig.QueueId

    if ($queueId) {
        $quickConnectQueueRefs[$queueId] = $true
    }
}

Write-Host "Quick Connect references loaded."
Write-Host ""

# ===============================
# SAFE DELETE PROCESS
# ===============================

foreach ($queueId in $queueIds) {

    Write-Host "Processing Queue: $queueId"

    $inRoutingProfile = $routingProfileQueueRefs.ContainsKey($queueId)
    $inQuickConnect   = $quickConnectQueueRefs.ContainsKey($queueId)

    if ($inRoutingProfile -or $inQuickConnect) {

        Write-Host "SKIPPED: Queue is still referenced"

        if ($inRoutingProfile) {
            Write-Host " - Referenced by Routing Profile"
        }

        if ($inQuickConnect) {
            Write-Host " - Referenced by Quick Connect"
        }

        Write-Host "------------------------------------"
        continue
    }

    Write-Host "Deleting Queue: $queueId"

    try {

        $result = aws connect delete-queue `
            --instance-id $InstanceId `
            --queue-id $queueId 2>&1

        if ($LASTEXITCODE -eq 0) {

            Write-Host "SUCCESS: Queue deleted -> $queueId"
        }
        else {

            Write-Host "ERROR deleting queue -> $queueId"
            Write-Host $result
        }

    }
    catch {

        Write-Host "EXCEPTION deleting queue -> $queueId"
        Write-Host $_
    }

    Write-Host "------------------------------------"
}

Write-Host ""
Write-Host "Safe deletion completed."