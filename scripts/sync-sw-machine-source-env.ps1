param(
  [string]$ShopOpsEnvPath = "C:\Users\Ryan\Bowlus Dropbox\Production Engineering\Engineering\Jacob Working\Projects\Bowlus Shop Ops\.env"
)

$ErrorActionPreference = "Stop"

Import-Module Posh-SSH

$shopOpsVars = @{}
Get-Content -LiteralPath $ShopOpsEnvPath | ForEach-Object {
  if ($_ -match "^\s*#" -or $_ -notmatch "=") {
    return
  }
  $parts = $_ -split "=", 2
  $shopOpsVars[$parts[0].Trim()] = $parts[1].Trim().Trim('"')
}

$secure = ConvertTo-SecureString $shopOpsVars["SW_MACHINE_SSH_PASSWORD"] -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($shopOpsVars["SW_MACHINE_SSH_USER"], $secure)
$session = New-SSHSession -ComputerName $shopOpsVars["SW_MACHINE_HOST"] -Credential $cred -AcceptKey -Force -ConnectionTimeout 10

try {
  $selected = @("AIRTABLE_PAT", "AIRTABLE_BASE", "ASANA_PAT")
$remoteScript = @'
$ErrorActionPreference = "Stop"
$envPath = "C:\Hawley\bowlus-hawley\.env"
$incomingJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("__INCOMING_JSON_B64__"))
$incoming = $incomingJson | ConvertFrom-Json

$lines = @()
if (Test-Path -LiteralPath $envPath) {
  $lines = Get-Content -LiteralPath $envPath
}

$existing = @{}
foreach ($line in $lines) {
  if ($line -match "^\s*#" -or $line -notmatch "=") {
    continue
  }
  $parts = $line -split "=", 2
  $existing[$parts[0].Trim()] = $parts[1]
}

foreach ($prop in $incoming.PSObject.Properties) {
  $existing[$prop.Name] = [string]$prop.Value
}

$orderedKeys = @(
  "PGHOST",
  "PGPORT",
  "PGDATABASE",
  "PGUSER",
  "PGPASSWORD",
  "DATABASE_URL",
  "POSTGRES_SUPERUSER_PASSWORD",
  "BOWLUS_APP_PASSWORD",
  "BOWLUS_READONLY_PASSWORD",
  "AIRTABLE_PAT",
  "AIRTABLE_BASE",
  "ASANA_PAT"
)

$out = @()
foreach ($key in $orderedKeys) {
  if ($existing.ContainsKey($key)) {
    $out += "$key=$($existing[$key])"
  }
}
foreach ($key in ($existing.Keys | Sort-Object)) {
  if ($orderedKeys -notcontains $key) {
    $out += "$key=$($existing[$key])"
  }
}

Set-Content -LiteralPath $envPath -Value $out -Encoding UTF8
Write-Output "Updated Hawley .env on SW_Machine with selected source-system credential pointers."
'@

  $incoming = @{}
  foreach ($key in $selected) {
    if ($shopOpsVars[$key]) {
      $incoming[$key] = $shopOpsVars[$key]
    }
  }
  $incomingJson = $incoming | ConvertTo-Json -Compress
  $incomingB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($incomingJson))
  $remoteScript = $remoteScript.Replace("__INCOMING_JSON_B64__", $incomingB64)
  $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($remoteScript))
  $result = Invoke-SSHCommand -SessionId $session.SessionId -Command "powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" -TimeOut 120
  $result.Output
  if ($result.Error) {
    $result.Error
  }
} finally {
  Remove-SSHSession -SessionId $session.SessionId | Out-Null
}
