# ===============================
# CONFIGURATION
# ===============================

# Your Amazon Connect Instance ID
$InstanceId = "YOUR_INSTANCE_ID"

# File paths
$routingProfileFile = "./filteredRoutingProfiles.txt"
$queueFilterFile    = "./filteredQueueList.txt"
$outputCsv          = "./MatchedRoutingProfileQueues.csv"

# ===============================
# STEP 1 - Get Routing Profiles
# ===============================

Write-Host "Retrieving routing profiles..."

$routingProfiles = aws connect list-routing-profiles `
    --instance-id $InstanceId `
    --query "RoutingProfileSummaryList[].Id" `
    --output text

# Save routing profile IDs
$routingProfiles -split "`t" | Out-File -FilePath $routingProfileFile -Encoding utf8

Write-Host "Routing profile list saved to $routingProfileFile"

# ===============================
# STEP 2 - Load Filter Queue List
# ===============================

if (!(Test-Path $queueFilterFile)) {
    Write-Host "ERROR: filteredQueueList.txt not found!"
    exit
}

$filteredQueues = Get-Content $queueFilterFile

# ===============================
# STEP 3 - Iterate Routing Profiles
# ===============================

Write-Host "Scanning routing profiles..."

$results = @()

$routingProfilesList = Get-Content $routingProfileFile

foreach ($routingProfileId in $routingProfilesList) {

    Write-Host "Checking Routing Profile: $routingProfileId"

    $queuesJson = aws connect list-routing-profile-queues `
        --instance-id $InstanceId `
        --routing-profile-id $routingProfileId `
        --output json

    $queues = $queuesJson | ConvertFrom-Json

    foreach ($queue in $queues.RoutingProfileQueueConfigSummaryList) {

        if ($filteredQueues -contains $queue.QueueId) {

            Write-Host "Match found: $($queue.QueueName)"

            $results += [PSCustomObject]@{
                RoutingProfileId = $routingProfileId
                QueueName        = $queue.QueueName
                QueueId          = $queue.QueueId
                ChannelType      = $queue.Channel
            }

        }
    }
}

# ===============================
# STEP 4 - Export CSV
# ===============================

$results | Export-Csv -Path $outputCsv -NoTypeInformation

Write-Host "Completed."
Write-Host "Results saved to $outputCsv"
