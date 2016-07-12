ChocolateyNodeJS.extension (Chocolatey Extension)
=================================================

A Chocolatey helper extension for installing Node.js applications.

## Commands

### Install-ChocolateyNodeApplication

Installs a node application from the 'content' folder of a Chocolatey package.

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
### Uninstall-ChocolateyNodeApplication

Uninstalls a node application from the 'content' folder of a Chocolatey package.

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


## Release Notes

### [1.1.2]

#### Changed

- In `Uninstall-ChocolateyNodeApplication`, fix bug in folder deletion.


For previous releases, see the [ChangeLog](ChangeLog.md).
