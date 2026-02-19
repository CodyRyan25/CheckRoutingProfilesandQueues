# ==============================
# CONFIGURATION
# ==============================

$InstanceId = "YOUR_CONNECT_INSTANCE_ID"
$QueueIdFile = "queueIds.txt"
$OutputFile = "QueueQuickConnectAudit.csv"

# ==============================
# LOAD QUEUE IDS
# ==============================

if (-not (Test-Path $QueueIdFile)) {
    Write-Host "Queue ID file not found: $QueueIdFile" -ForegroundColor Red
    return
}

$QueueIds = Get-Content $QueueIdFile | Where-Object { $_.Trim() -ne "" }

if (-not $QueueIds) {
    Write-Host "Queue ID file is empty." -ForegroundColor Red
    return
}

Write-Host "Loaded $($QueueIds.Count) Queue IDs from file."

# ==============================
# GET ALL QUEUES (FOR NAME LOOKUP)
# ==============================

Write-Host "Retrieving all queues for name mapping..."

$AllQueues = @()
$NextToken = $null

do {
    $Command = @(
        "connect", "list-queues",
        "--instance-id", $InstanceId,
        "--output", "json"
    )

    if ($NextToken) {
        $Command += @("--next-token", $NextToken)
    }

    $Response = aws @Command | ConvertFrom-Json
    $AllQueues += $Response.QueueSummaryList
    $NextToken = $Response.NextToken

} while ($NextToken)

$QueueLookup = @{}
foreach ($Queue in $AllQueues) {
    $QueueLookup[$Queue.Id] = $Queue.Name
}

# ==============================
# PROCESS EACH QUEUE
# ==============================

$Results = @()

foreach ($QueueId in $QueueIds) {

    Write-Host "Processing Queue: $QueueId"

    $QueueName = if ($QueueLookup.ContainsKey($QueueId)) {
        $QueueLookup[$QueueId]
    } else {
        "Unknown Queue"
    }

    # Pagination-safe quick connect listing
    $NextToken = $null
    do {

        $Command = @(
            "connect", "list-queue-quick-connects",
            "--instance-id", $InstanceId,
            "--queue-id", $QueueId,
            "--output", "json"
        )

        if ($NextToken) {
            $Command += @("--next-token", $NextToken)
        }

        $Response = aws @Command | ConvertFrom-Json
        $QuickConnects = $Response.QuickConnectSummaryList
        $NextToken = $Response.NextToken

        foreach ($QC in $QuickConnects) {

            # Get full quick connect details
            $QCDetails = aws connect describe-quick-connect `
                --instance-id $InstanceId `
                --quick-connect-id $QC.Id `
                --output json | ConvertFrom-Json

            $Config = $QCDetails.QuickConnect.QuickConnectConfig

            $Results += [PSCustomObject]@{
                QueueId            = $QueueId
                QueueName          = $QueueName
                QuickConnectId     = $QC.Id
                QuickConnectName   = $QC.Name
                QuickConnectType   = $Config.QuickConnectType
                ContactFlowId      = $Config.ContactFlowId
                DestinationQueueId = $Config.QueueConfig.QueueId
                DestinationUserId  = $Config.UserConfig.UserId
            }
        }

    } while ($NextToken)
}

# ==============================
# EXPORT RESULTS
# ==============================

$Results | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Host "Completed."
Write-Host "Results exported to $OutputFile" -ForegroundColor Cyan
