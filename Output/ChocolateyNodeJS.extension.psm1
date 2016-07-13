function Uninstall-ChocolateyNodeApplication {
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
}

function Uninstall-ChocolateyNodeWebsite {
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
}

function Install-ChocolateyNodeApplication {
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
}

function Install-ChocolateyNodeWebsite {
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
	
	$moduleDir = Split-Path $MyInvocation.MyCommand.Path -Parent
	
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
	$webConfigContent = Get-Content "$($moduleDir)\content\web.config" -Encoding 'utf8'
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
}

Export-ModuleMember -Function Install-ChocolateyNodeApplication
Export-ModuleMember -Function Install-ChocolateyNodeWebsite
Export-ModuleMember -Function Uninstall-ChocolateyNodeApplication
Export-ModuleMember -Function Uninstall-ChocolateyNodeWebsite
