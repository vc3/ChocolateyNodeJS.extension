Write-Verbose "Loading 'Psake-Utils\psake-tasks.ps1'..."

properties {
    Write-Verbose "Applying properties from 'Psake-Utils\psake-tasks.ps1'..."

    if (-not($projectName)) {
        $projectName = Split-Path $root -Leaf
    }

    $outDir = Join-Path $env:LOCALAPPDATA $projectName
    if (-not(Test-Path $outDir)) {
        New-Item $outDir -Type Directory | Out-Null
    }

    Write-Verbose "OutDir: $outDir"
}

task Utils:Help {
    Write-Host "TODO: Help for 'Psake-Utils' tasks."
}
