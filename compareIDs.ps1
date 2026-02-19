# ==============================
# CONFIGURATION
# ==============================

$QueueIdFile = "queueIds.txt"
$Step7File   = "step7.txt"
$OutputFile  = "QueueQuickConnectMatches.csv"

# ==============================
# VALIDATE FILES
# ==============================

if (-not (Test-Path $QueueIdFile)) {
    Write-Host "queueIds.txt not found." -ForegroundColor Red
    return
}

if (-not (Test-Path $Step7File)) {
    Write-Host "step7.txt not found." -ForegroundColor Red
    return
}

# ==============================
# LOAD REFERENCE QUEUE IDS
# ==============================

$ReferenceQueueIds = Get-Content $QueueIdFile | Where-Object { $_.Trim() -ne "" }

if (-not $ReferenceQueueIds) {
    Write-Host "queueIds.txt is empty." -ForegroundColor Red
    return
}

Write-Host "Loaded $($ReferenceQueueIds.Count) reference Queue IDs."

# ==============================
# LOAD STEP7 CONTENT
# ==============================

$Content = Get-Content $Step7File -Raw

# Split into blocks per Quick Connect
$Blocks = $Content -split "==============================="

$Results = @()

foreach ($Block in $Blocks) {

    if ($Block -match "QuickConnectId:\s*(\S+)") {

        $QuickConnectId = $Matches[1]

        foreach ($QueueId in $ReferenceQueueIds) {

            if ($Block -match [Regex]::Escape($QueueId)) {

                $Results += [PSCustomObject]@{
                    QueueId        = $QueueId
                    QuickConnectId = $QuickConnectId
                }
            }
        }
    }
}

# Remove duplicates (if any)
$Results = $Results | Sort-Object QueueId, QuickConnectId -Unique

# ==============================
# EXPORT CSV
# ==============================

if ($Results.Count -gt 0) {
    $Results | Export-Csv -Path $OutputFile -NoTypeInformation
    Write-Host "Matches found and exported to $OutputFile" -ForegroundColor Cyan
}
else {
    Write-Host "No matches found." -ForegroundColor Yellow
}
