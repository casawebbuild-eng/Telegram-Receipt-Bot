<#
Scans the repo for values that must never be pushed.
Pass your own values with -Patterns. Do not hard-code them in this file.

Usage:
  .\scripts\check-secrets.ps1 -Patterns "YOUR_CHAT_ID_NUMBER","your-ngrok-subdomain","start-of-your-sheet-id"

Exit code 0 = clean, 1 = something found.
#>
param(
    [string[]]$Patterns = @()
)

$root = Split-Path -Parent $PSScriptRoot
$files = Get-ChildItem -Path $root -Recurse -File -Force |
    Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.Extension -notin '.png', '.jpg', '.jpeg', '.gif', '.zip' }

$found = @()

# Generic secret shapes (regex)
$regexes = @(
    'AIza[0-9A-Za-z_\-]{35}',            # Google API key
    '\d{8,10}:[A-Za-z0-9_\-]{35}',       # Telegram bot token
    'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY',
    'sk-[A-Za-z0-9]{20,}',               # common API key prefix
    'ngrok-free\.(dev|app)(?<!YOUR-DOMAIN\.ngrok-free\.dev)'
)
foreach ($rx in $regexes) {
    $found += $files | Select-String -Pattern $rx
}

# Your own values (literal match)
if ($Patterns.Count -gt 0) {
    $found += $files | Select-String -Pattern $Patterns -SimpleMatch
}

# The placeholder domain is expected; drop it
$found = $found | Where-Object { $_.Line -notmatch 'YOUR-DOMAIN\.ngrok-free\.dev' }

if ($found.Count -gt 0) {
    Write-Host "FOUND possible secrets:" -ForegroundColor Red
    $found | ForEach-Object {
        $rel = $_.Path.Substring($root.Length + 1)
        Write-Host ("  {0}:{1}" -f $rel, $_.LineNumber)
    }
    exit 1
}
Write-Host "Clean: no secrets found in $($files.Count) files." -ForegroundColor Green
exit 0
