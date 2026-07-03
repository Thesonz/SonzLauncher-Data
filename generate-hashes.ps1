param(
    [Parameter(Mandatory = $true)]
    [string]$InstanceId
)
$ErrorActionPreference = "Stop"
$instanceRoot = Join-Path $PSScriptRoot "instances\$InstanceId"
$manifestPath = Join-Path $instanceRoot "instance.json"

if (!(Test-Path $manifestPath)) {
    throw "instance.json introuvable : $manifestPath"
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$prefix = $instanceRoot.TrimEnd('\') + '\'

$managedFolders = @(
    "mods",
    "config",
    "resourcepacks",
    "shaderpacks"
)

$files = foreach ($folder in $managedFolders) {
    $folderPath = Join-Path $instanceRoot $folder

    if (!(Test-Path $folderPath)) {
        continue
    }

    Get-ChildItem $folderPath -File -Recurse |
        Sort-Object FullName |
        ForEach-Object {
            $relativePath = $_.FullName.Substring($prefix.Length).Replace('\', '/')

            [ordered]@{
                path   = $relativePath
                source = "instances/$InstanceId/$relativePath"
                sha256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
            }
        }
}

if ($manifest.PSObject.Properties.Name -contains "files") {
    $manifest.files = @($files)
}
else {
    $manifest |
        Add-Member -NotePropertyName "files" -NotePropertyValue @($files)
}

# Actualiser également les hash des mondes ZIP
foreach ($world in $manifest.worlds) {
    $worldPath = Join-Path $PSScriptRoot (
        $world.source.Replace('/', '\')
    )

    if (Test-Path $worldPath) {
        $world.sha256 = (
            Get-FileHash $worldPath -Algorithm SHA256
        ).Hash.ToLower()
    }
}

$manifest |
    ConvertTo-Json -Depth 10 |
    Set-Content $manifestPath -Encoding UTF8

Write-Host "Manifest généré : $manifestPath"
Write-Host "$($files.Count) fichier(s) traité(s)."