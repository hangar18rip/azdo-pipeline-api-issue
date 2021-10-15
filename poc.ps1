[CmdletBinding()]
param (
    [securestring] $AzDOToken, # A PAT with project creation permission, 
    [string] $AzDOOrganization # Name of the org, not the complete URL
)

$ErrorActionPreference = "Stop"

$module = Get-InstalledModule VSTeam -ErrorAction SilentlyContinue
if (! $module) {
    Install-Module VSTeam -Force -Verbose -Scope CurrentUser
}

Set-VSTeamAccount -Account $AzDOOrganization -SecurePersonalAccessToken $AzDOToken

$projectName = "Prj" + [guid]::NewGuid().ToString("N")

# Creates a sample project
$p = Add-VSTeamProject -ProjectName $projectName -ProcessTemplate "Scrum"
$project = Get-VSTeamProject $projectName -IncludeCapabilities -ErrorAction SilentlyContinue
$vg = Add-VSTeamVariableGroup -Name SampleGroup -Type Vsts -Variables @{a = "b" }  -ProjectName $projectName

$repo = Get-VSTeamGitRepository -Name $projectName -ProjectName $projectName -ErrorAction SilentlyContinue
$TargetRepoUrl = $repo.InternalObject.remoteUrl

$targetDir = Join-Path -Path $env:TEMP -ChildPath $projectName
New-Item -Path $targetDir -ItemType Directory | Out-Null

Get-ChildItem -Path $PSScriptRoot | Copy-Item -Destination $targetDir

Push-Location $targetDir

git init
git remote add origin $TargetRepoUrl

Get-ChildItem | ForEach-Object { git add $_ }

git commit -m 'init'
git push --force --set-upstream origin master

$PipelineUrl = "https://dev.azure.com/$($AzDOOrganization)/$($projectName)/_apis/pipelines?api-version=6.1-preview.1"

$RequestBodyPath = [system.io.path]::Combine($PSScriptRoot, "rest-body.json")
$RequestBodyBase = Get-Content $RequestBodyPath -Raw
$ci = $RequestBodyBase.Replace("__RepoId__", $repo.Id).Replace("__RepoName__", $repo.Name)

$res = Invoke-VSTeamRequest -Url $PipelineUrl -method Post -body $ci -Verbose

Pop-Location
