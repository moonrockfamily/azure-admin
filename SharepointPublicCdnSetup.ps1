[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True,Position=1,ValueFromPipelineByPropertyName=$true)]
	[string]$SharepointSiteUrl,
	[Parameter(Mandatory=$True,Position=1,ValueFromPipelineByPropertyName=$true)]
	[string]$CdnOriginLibraryRelativePath
)

$ErrorActionPreference = "Stop"


function SharepointPublicCdnOriginExistsForLibrary($libraryUrl) {
	$origins = Get-SPOPublicCdnOrigins
	$existingOrigin = $origins | where Url -eq $libraryUrl
	return $existingOrigin
}

function SharepointManagementModuleExists() {
	$sharepointModule = get-module -name "Microsoft.Online.Sharepoint.Powershell"
	if ($sharepointModule -ne $null) {
		Write-Host -ForegroundColor "Yellow" "Found Sharepoint powershell module $($sharepointModule.Name) version $($sharepointModule.Version)"
	} else {
		Write-Error -ForegroundColor "DarkYellow" "Sharepoint powershell module not installed. See https://www.microsoft.com/en-ca/download/details.aspx?id=35588"
	}
}


SharepointManagementModuleExists
$publicCdnLibraryUrl = "$SharepointSiteUrl/$CdnOriginLibraryRelativePath"
$existingCdnOrigin = SharepointPublicCdnOriginExistsForLibrary $publicCdnLibraryUrl
if (-Not $existingCdnOrigin) {
	Write-Host -ForegroundColor "DarkYellow" "Missing public cdn origin library $publicCdnLibraryUrl"
	New-SPOPublicCdnOrigin $publicCdnLibraryUrl
} else {
	Write-Host -ForegroundColor "Yellow" "CDN public origin exists!"
	$existingCdnOrigin
}