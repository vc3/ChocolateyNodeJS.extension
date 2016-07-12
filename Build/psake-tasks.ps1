Write-Verbose "Loading 'Build\psake-tasks.ps1'..."

properties {
    Write-Verbose "Applying properties from 'Build\psake-tasks.ps1'..."

    $chocoOutDir = $outDir
    $chocoPkgsDir = $root
}

include '.\Build\Modules\Psake-Choco\psake-tasks.ps1'

task EnsureMyGetConnected {
	if (-not $chocoApiKey) {
		throw "Psake property 'chocoApiKey' must be configured."
	}
}

task Build -depends EnsureMyGetConnected,Choco:BuildPackages

task Deploy -depends EnsureMyGetConnected,Choco:DeployPackages
