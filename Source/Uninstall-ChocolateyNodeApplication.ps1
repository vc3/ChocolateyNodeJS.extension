<#
.SYNOPSIS

Uninstalls a node application found in the 'content' folder of a Chocolatey package.

.DESCRIPTION

* Removes files that were copied from the package's "**content**" folder.
	- Files are removed from the install `Path`.

These parameters have default values, so they are optional.

* `Path`: C:\\ProgramData\\{Name}

The defaults can be overridden in **package.json**.

```json
  "install": {
    "path": "C:\\ProgramData\\NodeApps\\MyApp"
  }
```

Finally, specified parameters take precedence.

.EXAMPLE

PS> Uninstall-ChocolateyNodeApplication 'MyApp'

Uninstalls the application using options in 'package.json', supplemented with the default options.

.EXAMPLE

PS> Uninstall-ChocolateyNodeApplication 'MyApp' -Path D:\MyApp

Uninstalls the application using the specified options.

#>
[CmdletBinding(PositionalBinding=$false)]
param(
    # The name of the node application.
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Enter the name of the Node.js application.")]
    [string]$Name,

    # The path to remove the application from, defaults to 'C:\ProgramData\{Name}'.
    [Parameter(Mandatory=$false)]
    [string]$Path,

    # The package command (install/uninstall) script path.
    [Parameter(Mandatory=$false)]
    [string]$CommandPath=$MyInvocation.PSCommandPath,

    [Parameter(Mandatory=$false)]
    [switch]$SuppressConfirmationMessage
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

if (-not($SuppressConfirmationMessage.IsPresent)) {
    Write-Host "Application uninstall complete."
}
