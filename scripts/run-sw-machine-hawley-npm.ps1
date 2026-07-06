param(
  [Parameter(Mandatory = $true)]
  [string[]]$NpmArgs,
  [string]$ShopOpsEnvPath = "C:\Users\Ryan\Bowlus Dropbox\Production Engineering\Engineering\Jacob Working\Projects\Bowlus Shop Ops\.env"
)

$ErrorActionPreference = "Stop"

Import-Module Posh-SSH

$vars = @{}
Get-Content -LiteralPath $ShopOpsEnvPath | ForEach-Object {
  if ($_ -match "^\s*#" -or $_ -notmatch "=") {
    return
  }
  $parts = $_ -split "=", 2
  $vars[$parts[0].Trim()] = $parts[1].Trim().Trim('"')
}

$secure = ConvertTo-SecureString $vars["SW_MACHINE_SSH_PASSWORD"] -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($vars["SW_MACHINE_SSH_USER"], $secure)
$session = New-SSHSession -ComputerName $vars["SW_MACHINE_HOST"] -Credential $cred -AcceptKey -Force -ConnectionTimeout 10

try {
  $escapedArgs = $NpmArgs | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }
  $command = 'cmd /c cd /d C:\Hawley\bowlus-hawley && "C:\Program Files\nodejs\npm.cmd" ' + ($escapedArgs -join " ")
  $result = Invoke-SSHCommand -SessionId $session.SessionId -Command $command -TimeOut 900
  $result.Output
  if ($result.Error) {
    $result.Error
  }
  if ($result.ExitStatus -ne 0) {
    throw "Remote npm command failed with exit status $($result.ExitStatus)."
  }
} finally {
  Remove-SSHSession -SessionId $session.SessionId | Out-Null
}
