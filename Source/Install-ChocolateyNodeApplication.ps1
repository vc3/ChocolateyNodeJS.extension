[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="The name of the node application.")]
    [string]$Name,

    [Parameter(Mandatory=$false, HelpMessage="The path to install the application to, defaults to 'C:\ProgramData\{Name}'.")]
    [string]$Path,

    [ValidateSet('Unspecified', 'Preserve', 'Purge')]
    [Parameter(Mandatory=$false, HelpMessage="How to handle extra files during upgrade, defaults to 'Preserve'.")]
    [string]$CopyMode='Unspecified',

    [Parameter(Mandatory=$false, HelpMessage="A pattern for directories to exclude, defaults to 'node_modules'.")]
    [string]$ExcludedDirectories,

    [Parameter(Mandatory=$false, HelpMessage="A pattern for source files to exclude, defaults to '*.excluded'.")]
    [string]$ExcludedFiles,

    [Parameter(Mandatory=$false, HelpMessage='The package command (install/uninstall) script path.')]
    [string]$CommandPath=$MyInvocation.PSCommandPath
)

Write-Host "Installing node application '$($Name)'..."

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
    if ($CopyMode -eq 'Unspecified' -and $packageJson.install.copyMode) {
        $CopyMode = $packageJson.install.copyMode
    }
    if (-not($ExcludedDirectories) -and $packageJson.install.excludedDirectories) {
        $ExcludedDirectories = $packageJson.install.excludedDirectories
    }
    if (-not($ExcludedFiles) -and $packageJson.install.excludedFiles) {
        $ExcludedFiles = $packageJson.install.excludedFiles
    }
}

# Defaults install settings
if (-not($Path)) {
    $Path = "C:\ProgramData\$($Name)"
}
if ($CopyMode -eq 'Unspecified') {
    $CopyMode = 'Preserve'
}
if (-not($ExcludedDirectories)) {
    $ExcludedDirectories = 'node_modules'
}
if (-not($ExcludedFiles)) {
    $ExcludedFiles = '*.excluded'
}

if (-not(Test-Path $Path)) {
    Write-Host "Creating install directory '$($Path)'..."
    New-Item $Path -Type Directory -Force | Out-Null
}

Write-Host "Copying application files to '$($Path)'..."
$copyFlag = if ($CopyMode -eq 'purge') { '/MIR' } else { '/E' }
robocopy """$($contentDir)""" """$($Path)""" $copyFlag /XD $ExcludedDirectories /XF $ExcludedFiles | Out-Null
if ($LastExitCode -ge 8) {
    # http://ss64.com/nt/robocopy-exit.html
    Write-Error "Failed to copy application files: robocopy exit code $($LastExitCode)."
}

Push-Location $Path
try {
    Write-Host "Installing node packages..."
    & npm install --production --no-optional | Out-Null
} finally {
    Pop-Location
}

Write-Host "Application install complete."
