<#
.SYNOPSIS

Uninstalls a node website found in the 'content' folder of a Chocolatey package.

.DESCRIPTION

* Stops and removes the existing site and app pool.
* Calls `Uninstall-ChocolateyNodeApplication` to remove the website files.

These parameters have default values, so they are optional.

* `Path`: C:\\inetpub\\{Name}

The defaults can be overridden in **package.json**.

```json
  "install": {
    "path": "C:\\inetpub\\node\\MySite"
  }
```

Finally, specified parameters take precedence.

.EXAMPLE

PS> Uninstall-ChocolateyNodeWebsite 'MySite'

Uninstalls the website using options in 'package.json', supplemented with the default options.

.EXAMPLE

PS> Uninstall-ChocolateyNodeApplication 'MySite' -Path D:\MySite

Uninstalls the website using the specified options.

#>
[CmdletBinding(PositionalBinding=$false)]
param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="The name of the node application.")]
    [string]$Name,

    [Parameter(Mandatory=$false, HelpMessage="The path to remove the application from, defaults to 'C:\inetpub\{Name}'.")]
    [string]$Path,

    [Parameter(Mandatory=$false, HelpMessage='The package command (install/uninstall) script path.')]
    [string]$CommandPath=$MyInvocation.PSCommandPath,

    [Parameter(Mandatory=$false)]
    [switch]$SuppressConfirmationMessage
)

Import-Module WebAdministration -Force

$moduleDir = Split-Path $MyInvocation.MyCommand.Path -Parent

Write-Host "Uninstalling node website '$($Name)'..."

$site = Get-Website -Name $Name
if ($site) {
    if ($site.State -eq 'Started') {
        Write-Host "Stopping website..."
        Stop-Website -Name $Name | Out-Null
    }

    Write-Host "Removing website..."
    Remove-Website -Name $Name | Out-Null

    $webAppPoolExists = $null
    try {
        Get-WebAppPoolState -Name $Name | Out-Null
        $webAppPoolExists = $true
    } catch {
        # Do nothing...
    }
    if ($webAppPoolExists) {
        Write-Host "Removing app pool..."
        Remove-WebAppPool -Name $Name | Out-Null
    }
}

Write-Host "Waiting on w3wp to shut down." -NoNewLine
$w3wp = $null
$pollCount = 0
do {
    Write-Host "." -NoNewLine
    if ($pollCount -gt 0) {
        sleep 1
    } elseif ($pollCount -ge 10) {
        Write-Host ""
        Write-Host "Killing w3wp..."
        Get-CimInstance Win32_Process -Filter "name = 'w3wp.exe'" | `
            Where-Object { (Invoke-CimMethod -InputObject $_ -MethodName GetOwner).User -eq $Name } | `
            ForEach-Object { taskkill.exe /PID $_.ProcessId /F }
        break
    }
    $w3wp = Get-CimInstance Win32_Process -Filter "name = 'w3wp.exe'" | `
        Where-Object { (Invoke-CimMethod -InputObject $_ -MethodName GetOwner).User -eq $Name }
    $pollCount += 1
} while ($w3wp);

if ($pollCount -lt 10) {
    Write-Host ""
}

$packagePath = Get-ChocolateyPackagePath -CommandPath $CommandPath

$contentDir = Join-Path $packagePath 'content'
if (-not(Test-Path $contentDir)) {
    Write-Error "No 'content' directory in package."
    return
}

if (-not(Test-Path "$($contentDir)\package.json")) {
    Write-Error "No 'package.json' in content directory."
    return
}

# Read install settings from package.json
$packageJson = (Get-Content "$($contentDir)\package.json") -join "`n" |  ConvertFrom-Json
if ($packageJson.install) {
    Write-Host "Reading custom install settings from 'package.json'..."
    if (-not($Path) -and $packageJson.install.path) {
        $Path = $packageJson.install.path
    }
}

if (-not($Path)) {
    $Path = "$($env:SystemDrive)\inetpub\$($Name)"
}

# Remove ("uninstall") the website files
Uninstall-ChocolateyNodeApplication `
    -Name $Name `
    -Path $Path `
    -CommandPath $CommandPath `
    -SuppressConfirmationMessage

Write-Host "Website uninstall complete."
