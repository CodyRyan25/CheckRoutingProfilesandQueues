# ================================
# AWS Connect Routing Profile Filter Script
# ================================

# ---- Variables ----
$instanceId = "YOUR_INSTANCE_ID"

$unfilteredFile = "unfilteredSearchRoutingProfiles.txt"
$queueListFile  = "newFilteredQueueList.txt"
$outputCsv      = "FilteredRoutingProfiles.csv"

Write-Host "Starting routing profile search..." -ForegroundColor Cyan

# ---- Step 1: Pull Routing Profiles ----
Write-Host "Running search-routing-profiles..."

aws connect search-routing-profiles `
    --instance-id $instanceId `
    --max-results 500 `
    --query "RoutingProfiles" `
    --output json | Out-File $unfilteredFile

Write-Host "Routing profiles saved to $unfilteredFile"


# ---- Step 2: Load Queue List ----
if (!(Test-Path $queueListFile)) {
    Write-Host "ERROR: Queue list file not found: $queueListFile" -ForegroundColor Red
    exit
}

$queueIds = Get-Content $queueListFile | Where-Object { $_.Trim() -ne "" }

Write-Host "Loaded $($queueIds.Count) queue IDs"


# ---- Step 3: Load Routing Profiles ----
if (!(Test-Path $unfilteredFile)) {
    Write-Host "ERROR: Routing profile file not found." -ForegroundColor Red
    exit
}

$routingProfiles = Get-Content $unfilteredFile | ConvertFrom-Json


# ---- Step 4: Filter Matches ----
$results = @()

foreach ($profile in $routingProfiles) {

    $queueId = $profile.DefaultOutboundQueueId

    if ($queueIds -contains $queueId) {

        $results += [PSCustomObject]@{
            RoutingProfileName = $profile.Name
            RoutingProfileId   = $profile.Id
            QueueName          = $profile.DefaultOutboundQueueName
            QueueId            = $queueId
        }

        Write-Host "Match Found:" $profile.Name "->" $queueId -ForegroundColor Green
    }
}


# ---- Step 5: Export CSV ----
if ($results.Count -gt 0) {

    $results | Export-Csv $outputCsv -NoTypeInformation

    Write-Host ""
    Write-Host "CSV Created:" $outputCsv -ForegroundColor Cyan
    Write-Host "Matches Found:" $results.Count

} else {

    Write-Host "No matches found." -ForegroundColor Yellow

}

Write-Host "Script Complete."
