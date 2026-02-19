# ==============================
# CONFIGURATION
# ==============================

$InstanceId = "YOUR_CONNECT_INSTANCE_ID"
$TargetQueueName = "YOUR_QUEUE_NAME"
$OutputFile = "RoutingProfileQueueAudit.csv"

# ==============================
# FUNCTION: GET ALL QUEUES (Pagination Safe)
# ==============================

Write-Host "Retrieving all queues..."

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

if (-not $AllQueues) {
    Write-Host "No queues found." -ForegroundColor Red
    return
}

# Find target queue
$TargetQueue = $AllQueues | Where-Object { $_.Name -eq $TargetQueueName }

if (-not $TargetQueue) {
    Write-Host "Queue '$TargetQueueName' not found." -ForegroundColor Red
    return
}

$TargetQueueId = $TargetQueue.Id
Write-Host "Target Queue Found: $TargetQueueName ($TargetQueueId)" -ForegroundColor Green

# ==============================
# FUNCTION: GET ALL ROUTING PROFILES (Pagination Safe)
# ==============================

Write-Host "Retrieving all routing profiles..."

$AllRoutingProfiles = @()
$NextToken = $null

do {
    $Command = @(
        "connect", "list-routing-profiles",
        "--instance-id", $InstanceId,
        "--output", "json"
    )

    if ($NextToken) {
        $Command += @("--next-token", $NextToken)
    }

    $Response = aws @Command | ConvertFrom-Json
    $AllRoutingProfiles += $Response.RoutingProfileSummaryList
    $NextToken = $Response.NextToken

} while ($NextToken)

if (-not $AllRoutingProfiles) {
    Write-Host "No routing profiles found." -ForegroundColor Red
    return
}

# ==============================
# CHECK ASSOCIATIONS
# ==============================

Write-Host "Checking routing profile associations..."

$Results = @()

foreach ($Profile in $AllRoutingProfiles) {

    $ProfileDetails = aws connect describe-routing-profile `
        --instance-id $InstanceId `
        --routing-profile-id $Profile.Id `
        --output json | ConvertFrom-Json

    $AssociatedQueues = $ProfileDetails.RoutingProfile.QueueConfigs

    $Match = $AssociatedQueues | Where-Object { $_.QueueReference.QueueId -eq $TargetQueueId }

    $Results += [PSCustomObject]@{
        RoutingProfileName = $Profile.Name
        RoutingProfileId   = $Profile.Id
        QueueName          = $TargetQueueName
        QueueId            = $TargetQueueId
        IsAssociated       = if ($Match) { $true } else { $false }
    }
}

# ==============================
# EXPORT TO CSV
# ==============================

$Results | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Host "Completed."
Write-Host "Results exported to $OutputFile" -ForegroundColor Cyan

