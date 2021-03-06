﻿Commands
========

## Install-ChocolateyNodeApplication

Installs a node application found in the 'content' folder of a Chocolatey package.

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

**Examples:**

```PowerShell
Install-ChocolateyNodeApplication 'MyApp'
```

Installs the application using options in 'package.json', supplemented with the default options.    

```PowerShell
Install-ChocolateyNodeApplication 'MyApp' -Path D:\MyApp -ExcludedDirectories 'data' -ExcludedFiles '*.log' -CopyMode 'Purge'
```

Installs the application using the specified options.    

## Install-ChocolateyNodeWebsite

Installs a node website found in the 'content' folder of a Chocolatey package and hosts in IIS via iisnode.

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

**Examples:**

```PowerShell
Install-ChocolateyNodeWebsite 'MySite'
```

Installs the website using options in 'package.json', supplemented with the default options.    

```PowerShell
Install-ChocolateyNodeApplication 'MySite' -Port 80 -Path D:\MySite -ExcludedDirectories 'data' -ExcludedFiles '*.log' -CopyMode 'Purge'
```

Installs the website using the specified options.    

## Uninstall-ChocolateyNodeApplication

Uninstalls a node application found in the 'content' folder of a Chocolatey package.

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

**Examples:**

```PowerShell
Uninstall-ChocolateyNodeApplication 'MyApp'
```

Uninstalls the application using options in 'package.json', supplemented with the default options.    

```PowerShell
Uninstall-ChocolateyNodeApplication 'MyApp' -Path D:\MyApp
```

Uninstalls the application using the specified options.    

## Uninstall-ChocolateyNodeWebsite

Uninstalls a node website found in the 'content' folder of a Chocolatey package.

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

**Examples:**

```PowerShell
Uninstall-ChocolateyNodeWebsite 'MySite'
```

Uninstalls the website using options in 'package.json', supplemented with the default options.    

```PowerShell
Uninstall-ChocolateyNodeApplication 'MySite' -Path D:\MySite
```

Uninstalls the website using the specified options.
