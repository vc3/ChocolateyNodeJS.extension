Write-Verbose "Loading 'Build\psake-tasks.ps1'..."

properties {
    Write-Verbose "Applying properties from 'Build\psake-tasks.ps1'..."

    $chocoOutDir = $outDir
    $chocoPkgsDir = "$root\Output"
}

include '.\Build\Modules\Psake-Choco\psake-tasks.ps1'

task EnsureApiKey {
	if (-not $chocoApiKey) {
		throw "Psake property 'chocoApiKey' must be configured."
	}
}

task UpdateOutput {
    $version = (Get-Content "$root\Build\version.txt").Trim()
    if ($version -match '-') {
        $isPrerelease = $true
        $versionNumber = [System.Version]::Parse($version.Split('-')[0])
    } else {
        $isPrerelease = $false
        $versionNumber = [System.Version]::Parse($version)
    }

    Write-Message "Building module 'ChocolateyNodeJS.extension'..."
    Invoke-ScriptBuild -Name 'ChocolateyNodeJS.extension' -SourcePath "$root\Source" -TargetPath "$root\Output" -Force

    $cmdletNames = @()
    $cmdletFiles = @()
    $cmdletDocs = @{}
    $cmdletSummaries = @{}

    Get-ChildItem "$root\Source" -Filter *.ps1 | foreach {
        $cmdletFile = $_.FullName
        $cmdletName = [IO.Path]::GetFileNameWithoutExtension($cmdletFile)
        $cmdletHelp = Get-Help $cmdletFile
        $cmdletData = @{cmdletName=$cmdletName;cmdletFile=$cmdletFile;cmdletHelp=$cmdletHelp}
        $cmdletTemplateFile = Join-Path $root "Build\Templates\CmdletDocumentation.md"
        $cmdletDocumentation = Expand-Template -File $cmdletTemplateFile -Binding $cmdletData

        $cmdletNames += $cmdletName
        $cmdletFiles += $cmdletFile
        $cmdletDocs[$cmdletName] = $cmdletDocumentation
        $cmdletSummaries[$cmdletName] = $cmdletHelp.Synopsis
    }

    $releaseNotes = @()

    $isInVersion = $null
    Get-Content "$root\ChangeLog.md" | foreach {
        if ($isInVersion) {
            if ([string]::IsNullOrWhitespace($_)) {
                $isInVersion = $false
            } else {
                $releaseNotes += "$_"
            }
        } elseif ($isInVersion -eq $null) {
            if (-not($isPreRelease) -and $_.StartsWith("## [$($versionNumber)]")) {
                $isInVersion = $true
                $releaseNotes += "## [$($versionNumber)]"
            } elseif ($isPreRelease -and $_.StartsWith("## Unreleased")) {
                $isInVersion = $true
                $releaseNotes += "## [$($versionNumber)]"
            }
        }
    }

    $pkgData = @{version=$version;cmdletNames=$cmdletNames;cmdletFiles=$cmdletFiles;cmdletSummaries=$cmdletSummaries;cmdletDocs=$cmdletDocs;releaseNotes=$releaseNotes}

    Write-Message "Generating 'ChocolateyNodeJS.extension.nuspec' from template..."
	$nuspecFile = Join-Path $root "Output\$($projectName).nuspec"
	$nuspecTemplateFile = Join-Path $root "Build\Templates\ChocolateyPackage.nuspec"
	$nuspecContent = Expand-Template -File $nuspecTemplateFile -Binding $pkgData
	($nuspecContent.Trim() -split "`n") -join "`r`n" | Out-File "$($nuspecFile)" -Encoding UTF8

    Write-Message "Setting version in 'ChocolateyNodeJS.extension.psd1'..."
    ((Get-Content "$root\Output\ChocolateyNodeJS.extension.psd1" | foreach {
        if ($_ -match "^ModuleVersion = '(.*)'$") {
            $_ -replace "^ModuleVersion = '(.*)'$", "ModuleVersion = '$($versionNumber)'"
        } else {
            $_
        }
    }) -join "`r`n") | Out-File "$root\Output\ChocolateyNodeJS.extension.psd1" -Encoding UTF8

    Write-Message "Generating 'ChocolateyNodeJS.extension.md' from template..."
	$documentationFile = Join-Path $root "Output\$($projectName).md"
	$documentationTemplateFile = Join-Path $root "Build\Templates\ModuleDocumentation.md"
	$documentationContent = Expand-Template -File $documentationTemplateFile -Binding $pkgData
	($documentationContent.Trim() -split "`n") -join "`r`n" | Out-File "$($documentationFile)" -Encoding UTF8
}

task Build -depends EnsureApiKey,UpdateOutput,Choco:BuildPackages

task Deploy -depends EnsureApiKey,Choco:DeployPackages
