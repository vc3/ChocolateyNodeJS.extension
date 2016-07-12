<#
.SYNOPSIS

Installs a node application found in the 'content' folder of a Chocolatey package.

.DESCRIPTION

* Copies files from the package's "**content**" folder.
	- Files are copied to the install `Path`.
	- Optional exclusion based on `ExcludedDirectories` and `ExcludedFiles`.
	- **Preserve** or **Purge** files in the destination based on `CopyMode`.
* Installs module dependencies, via: `npm install --production --no-optional`.

These parameters have default values, so they are optional.

* `Path`: C:\\ProgramData\\{Name}
* `ExcludedDirectories`: 'node_modules' *(restored via `npm install`)*
* `ExcludedFiles`: *.excluded
* `CopyMode`: Preserve

The defaults can be overridden in **package.json**.

```json
  "install": {
    "path": "C:\\ProgramData\\NodeApps\\MyApp",
    "copyMode": "Purge",
    "excludedDirectories": "node_modules",
    "excludedFiles": "*.ignore"
  }
```

Finally, specified parameters take precedence.

.EXAMPLE

PS> Install-ChocolateyNodeApplication 'MyApp'

Installs the application using options in 'package.json', supplemented with the default options.

.EXAMPLE

PS> Install-ChocolateyNodeApplication 'MyApp' -Path D:\MyApp -ExcludedDirectories 'data' -ExcludedFiles '*.log' -CopyMode 'Purge'

Installs the application using the specified options.

#>
[CmdletBinding(PositionalBinding=$false)]
param(
    # The name of the node application.
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Enter the name of the Node.js application.")]
    [string]$Name,

    # The path to install the application to, defaults to 'C:\ProgramData\{Name}'.
    [Parameter(Mandatory=$false)]
    [string]$Path,

    # How to handle extra files during upgrade, defaults to 'Preserve'.
    [ValidateSet('Unspecified', 'Preserve', 'Purge')]
    [Parameter(Mandatory=$false)]
    [string]$CopyMode='Unspecified',

    # A pattern for directories to exclude, defaults to 'node_modules'.
    [Parameter(Mandatory=$false)]
    [string]$ExcludedDirectories,

    # A pattern for source files to exclude, defaults to '*.excluded'.
    [Parameter(Mandatory=$false)]
    [string]$ExcludedFiles,

    # The package command (install/uninstall) script path.
    [Parameter(Mandatory=$false)]
    [string]$CommandPath=$MyInvocation.PSCommandPath,

    [Parameter(Mandatory=$false)]
    [switch]$SuppressConfirmationMessage
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

if (-not($SuppressConfirmationMessage.IsPresent)) {
    Write-Host "Application install complete."
}
