# ==============================
# CONFIGURATION
# ==============================

$InstanceId = "YOUR_CONNECT_INSTANCE_ID"
$QueueIdFile = "queueIds.txt"
$OutputFile = "QuickConnectQueueReferenceAudit.csv"

# ==============================
# LOAD QUEUE IDS FROM FILE
# ==============================

if (-not (Test-Path $QueueIdFile)) {
    Write-Host "Queue ID file not found: $QueueIdFile" -ForegroundColor Red
    return
}

$ReferenceQueueIds = Get-Content $QueueIdFile | Where-Object { $_.Trim() -ne "" }

if (-not $ReferenceQueueIds) {
    Write-Host "Queue ID file is empty." -ForegroundColor Red
    return
}

Write-Host "Loaded $($ReferenceQueueIds.Count) reference Queue IDs."

# ==============================
# GET ALL QUEUES (FOR NAME LOOKUP)
# ==============================

Write-Host "Retrieving queues for name mapping..."

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

# Create lookup dictionary
$QueueLookup = @{}
foreach ($Queue in $AllQueues) {
    $QueueLookup[$Queue.Id] = $Queue.Name
}

# ==============================
# LIST QUICK CONNECTS (QUEUE TYPE ONLY)
# ==============================

Write-Host "Retrieving QUEUE-type Quick Connects..."

$AllQuickConnects = @()
$NextToken = $null

do {
    $Command = @(
        "connect", "list-quick-connects",
        "--instance-id", $InstanceId,
        "--quick-connect-types", "QUEUE",
        "--output", "json"
    )

    if ($NextToken) {
        $Command += @("--next-token", $NextToken)
    }

    $Response = aws @Command | ConvertFrom-Json
    $AllQuickConnects += $Response.QuickConnectSummaryList
    $NextToken = $Response.NextToken

} while ($NextToken)

if (-not $AllQuickConnects) {
    Write-Host "No QUEUE-type Quick Connects found." -ForegroundColor Yellow
    return
}

Write-Host "Found $($AllQuickConnects.Count) QUEUE-type Quick Connect(s)."

# ==============================
# DESCRIBE + CHECK MATCH
# ==============================

$Results = @()

foreach ($QC in $AllQuickConnects) {

    Write-Host "Checking Quick Connect: $($QC.Name)"

    $QCDetails = aws connect describe-quick-connect `
        --instance-id $InstanceId `
        --quick-connect-id $QC.Id `
        --output json | ConvertFrom-Json

    $DestinationQueueId = $QCDetails.QuickConnect.QuickConnectConfig.QueueConfig.QueueId

    $IsMatch = $ReferenceQueueIds -contains $DestinationQueueId

    $QueueName = if ($QueueLookup.ContainsKey($DestinationQueueId)) {
        $QueueLookup[$DestinationQueueId]
    } else {
        "Unknown Queue"
    }

    $Results += [PSCustomObject]@{
        QueueId           = $DestinationQueueId
        QueueName         = $QueueName
        QuickConnectName  = $QC.Name
        QuickConnectId    = $QC.Id
        IsMatch           = $IsMatch
    }
}

# ==============================
# EXPORT RESULTS
# ==============================

$Results | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Host "Completed."
Write-Host "Results exported to $OutputFile" -ForegroundColor Cyan
