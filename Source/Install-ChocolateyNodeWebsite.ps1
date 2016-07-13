<#
.SYNOPSIS

Installs a node website found in the 'content' folder of a Chocolatey package and hosts in iisnode.

.DESCRIPTION

* Stops the existing website (if `-StopSite` is specified).
* Calls `Install-ChocolateyNodeApplication` to copy the relevant application files.
* Creates a default 'iisnode.yml' config file if one does not exist (first-time install).
* Creates the 'web.config' file.
* Creates and/or starts the website.

Both 'Name' and 'Port' are required (though, 'Port' may be specified in 'package.json').

These parameters have default values, so they are optional.

* `Path`: C:\\inetpub\\{Name}
* `StartScript`: server.js
* `ExcludedDirectories`: 'node_modules' *(restored via `npm install`)*
* `ExcludedFiles`: *.excluded
* `CopyMode`: Preserve

The defaults can be overridden in **package.json**.

```json
  "install": {
    "path": "C:\\inetpub\\node\\MySite",
    "copyMode": "preserve",
    "excludedDirectories": "node_modules",
    "excludedFiles": "iisnode.yml",
    "startScript": "main.js",
    "port": 8080
  }
```

Finally, specified parameters take precedence.

.EXAMPLE

PS> Install-ChocolateyNodeWebsite 'MySite'

Installs the website using options in 'package.json', supplemented with the default options.

.EXAMPLE

PS> Install-ChocolateyNodeApplication 'MySite' -Port 80 -Path D:\MySite -ExcludedDirectories 'data' -ExcludedFiles '*.log' -CopyMode 'Purge'

Installs the website using the specified options.

#>
[CmdletBinding(PositionalBinding=$false)]
param(
    # The name of the node website.
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Enter the name of the Node.js website.")]
    [string]$Name,

    # The port number (must be specified if not found in 'package.json').
    [Parameter(Mandatory=$false)]
    [int]$Port=0,

    # The path to install the website to, defaults to 'C:\inetpub\{Name}'.
    [Parameter(Mandatory=$false)]
    [string]$Path,

    # The script that runs the website, defaults to 'server.js'.
    [Parameter(Mandatory=$false)]
    [string]$StartScript,

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

    # If true, the site is stopped before an upgrade occurs.
    [Parameter(Mandatory=$false)]
    [switch]$StopSite,

    # The package command (install/uninstall) script path.
    [Parameter(Mandatory=$false)]
    [string]$CommandPath=$MyInvocation.PSCommandPath
)

Import-Module WebAdministration -Force

$moduleContentDir = Join-Path $PSScriptRoot 'content'
#ifdef SOURCE
$moduleContentDir = Join-Path (Split-Path $PSSriptRoot -Parent) 'Output\content'
#endif

Write-Host "Installing node website '$($Name)'..."

$site = Get-Website -Name $Name

if ($StopSite.IsPresent -and $site -and $site.State -eq 'Started') {
    Write-Host "Stopping website '$($Name)'..."
    Stop-Website -Name $Name | Out-Null
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
    if ($Port -eq 0 -and $packageJson.install.port) {
        $Port = $packageJson.install.port
    }
    if (-not($Path) -and $packageJson.install.path) {
        $Path = $packageJson.install.path
    }
    if (-not($StartScript) -and $packageJson.install.startScript) {
        $StartScript = $packageJson.install.startScript
    }
}

if ($Port -eq 0) {
    Write-Error "Port number is required."
    return
}

if (-not($Path)) {
    $Path = "$($env:SystemDrive)\inetpub\$($Name)"
}

if (-not($StartScript)) {
    # https://docs.npmjs.com/misc/scripts#default-values
    $StartScript = 'server.js'
}

$startScriptPath = Join-Path $contentDir $StartScript
if (-not(Test-Path $startScriptPath)) {
    Write-Error "Start script '$($StartScript)' doesn't exist."
}

# Copy and "install" the application files
Install-ChocolateyNodeApplication `
    -Name $Name `
    -Path $Path `
    -CopyMode $CopyMode `
    -ExcludedDirectories $ExcludedDirectories `
    -ExcludedFiles $ExcludedFiles `
    -CommandPath $CommandPath `
    -SuppressConfirmationMessage

# Copy a default 'iisnode.yml' file if one doesn't exist.
# Customizations can be made afterwards and will not be ovewritten.
$ymlConfigFile = Join-Path $Path 'iisnode.yml'
if (-not(Test-Path $ymlConfigFile)) {
    Write-Host "Copying default yml file..."
    Copy-Item (Join-Path "$($packageDir)\content" 'iisnode.yml') $ymlConfigFile | Out-Null
}

# Create a simple, managed web.config. This should not be edited. Customizations should be made in 'iisnode.yml' instead.
# "The optional iisnode.yml file provides overrides of the iisnode configuration settings specified in web.config."
# https://github.com/tjanczuk/iisnode/blob/master/src/samples/configuration/iisnode.yml
$webConfigContent = Get-Content "$($moduleContentDir)\content\web.config" -Encoding 'utf8'
$webConfigContent | ForEach-Object { $_ -replace '{{StartScript}}', $StartScript } | Out-File "$($Path)\web.config" -Encoding 'utf8'

# Start or create the IIS website

$appPoolExists = $null
$appPoolRunning = $null

if ($site) {
    if ($site.State -ne 'Started') {
        Write-Host "Starting website '$($Name)'..."
        Start-Website -Name $Name
    }
} else {
    Write-Host "Creating website..."
    New-WebAppPool -Name $Name | Out-Null
    New-Website -Name $Name -Port $Port -PhysicalPath $Path -ApplicationPool $Name | Out-Null
}

Write-Host "Website install complete."
