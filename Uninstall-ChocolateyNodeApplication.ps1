[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="The name of the node application.")]
    [string]$Name,

    [Parameter(Mandatory=$false, HelpMessage="The path to remove the application from, defaults to 'C:\ProgramData\{Name}'.")]
    [string]$Path,

    [Parameter(Mandatory=$false, HelpMessage='The package command (install/uninstall) script path.')]
    [string]$CommandPath=$MyInvocation.PSCommandPath
)

Write-Host "Uninstalling node application '$($Name)'..."

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

# Defaults install settings
if (-not($Path)) {
    $Path = "C:\ProgramData\$($Name)"
}

if (-not(Test-Path $Path)) {
    Write-Host "Install directory '$($Path)' does not exist."
    return
}

# NOTE: May have to use rimraf...
Write-Host "Removing application files from '$($Path)'..."
Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
if (Test-Path $Path) {
    Remove-Item $Path -Recurse -Force | Out-Null
}

Write-Host "Application uninstall complete."
