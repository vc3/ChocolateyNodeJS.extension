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
    Write-Message "Building module 'ChocolateyNodeJS.extension'..."
    Invoke-ScriptBuild -Name 'ChocolateyNodeJS.extension' -SourcePath "$root\Source" -TargetPath "$root\Output" -Force

    $version = '1.1.2'

    $cmdletDocumentation = ''

    Get-ChildItem "$root\Source" -Filter *.ps1 | foreach {
        $cmdletPath = $_.FullName
        $cmdletHelp = Get-Help $cmdletPath
        $cmdletData = @{cmdletPath=$cmdletPath;cmdletHelp=$cmdletHelp}
        $cmdletTemplatePath = Join-Path $root "Build\Templates\CmdletDocumentation.md.eps"
        $cmdletDocumentation += Expand-Template -File $cmdletTemplatePath -Binding $cmdletData
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
            if ($_.StartsWith("## [$($version)]")) {
                $isInVersion = $true
                $releaseNotes += "## [$($version)]"
            }
        }
    }

    Write-Message "Generating 'ChocolateyNodeJS.extension.nuspec' from template..."
    $nuspecData = @{version=$version;cmdletDocumentation=$cmdletDocumentation;releaseNotes=$releaseNotes}
	$nuspecPath = Join-Path $root "Output\$($projectName).nuspec"
	$nuspecTemplatePath = Join-Path $root "Build\Templates\$($projectName).nuspec.eps"
	$nuspecContent = Expand-Template -File $nuspecTemplatePath -Binding $nuspecData
	($nuspecContent.Trim() -split "`n") -join "`r`n" | Out-File "$($nuspecPath)" -Encoding UTF8

    Write-Message "Generating 'README.md' from template..."
    $readmeData = @{cmdletDocumentation=$cmdletDocumentation;releaseNotes=$releaseNotes}
	$readmePath = Join-Path $root "README.md"
	$readmeTemplatePath = Join-Path $root "Build\Templates\README.md.eps"
	$readmeContent = Expand-Template -File $readmeTemplatePath -Binding $readmeData
	($readmeContent.Trim() -split "`n") -join "`r`n" | Out-File "$($readmePath)" -Encoding UTF8
}

task Build -depends EnsureApiKey,UpdateOutput,Choco:BuildPackages

task Deploy -depends EnsureApiKey,Choco:DeployPackages
