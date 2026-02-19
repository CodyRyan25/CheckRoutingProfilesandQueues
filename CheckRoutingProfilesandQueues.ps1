# ==============================
# CONFIGURATION
# ==============================

$InstanceId = "YOUR_CONNECT_INSTANCE_ID"
$QueueIdFile = "queueIds.txt"
$OutputFile = "RoutingProfileQueueAudit.csv"

# ==============================
# LOAD TARGET QUEUE IDS FROM FILE
# ==============================

if (-not (Test-Path $QueueIdFile)) {
    Write-Host "Queue ID file not found: $QueueIdFile" -ForegroundColor Red
    return
}

$TargetQueueIds = Get-Content $QueueIdFile | Where-Object { $_.Trim() -ne "" }

if (-not $TargetQueueIds) {
    Write-Host "Queue ID file is empty." -ForegroundColor Red
    return
}

Write-Host "Loaded $($TargetQueueIds.Count) Queue IDs from file."

# ==============================
# OPTIONAL: GET ALL QUEUES (To Map ID -> Name)
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

# Create lookup table for QueueId -> QueueName
$QueueLookup = @{}
foreach ($Queue in $AllQueues) {
    $QueueLookup[$Queue.Id] = $Queue.Name
}

# ==============================
# GET ALL ROUTING PROFILES (Pagination Safe)
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

    $AssociatedQueueIds = $ProfileDetails.RoutingProfile.QueueConfigs |
        ForEach-Object { $_.QueueReference.QueueId }

    foreach ($QueueId in $TargetQueueIds) {

        $IsMatch = $AssociatedQueueIds -contains $QueueId

        $QueueName = if ($QueueLookup.ContainsKey($QueueId)) {
            $QueueLookup[$QueueId]
        } else {
            "Unknown Queue"
        }

        $Results += [PSCustomObject]@{
            RoutingProfileName = $Profile.Name
            RoutingProfileId   = $Profile.Id
            QueueId            = $QueueId
            QueueName          = $QueueName
            IsAssociated       = $IsMatch
        }
    }
}

# ==============================
# EXPORT TO CSV
# ==============================

$Results | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Host "Completed."
Write-Host "Results exported to $OutputFile" -ForegroundColor Cyan
