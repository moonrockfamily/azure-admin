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

function ImportModuleIfExists($moduleName, $downloadUrl) {
	$module = get-module -name $moduleName
	if ($module -ne $null) {
		Write-Host -ForegroundColor "Yellow" "Module $($module.Name) version $($module.Version) already loaded."
	} else {
		$availableModule = get-module -name $moduleName -listavailable
		if ($availableModule) {
			Write-Host -ForegroundColor "Yellow" "Importing module $($availableModule.Name) version $($availableModule.Version)."
			import-module $availableModule.Name
		} else {
			# try to install from central repo by name
			Write-Host -ForegroundColor "Yellow" "Installing module $moduleName."
			try {
				install-module $moduleName -ErrorAction "continue" -WarningAction "continue"
			} catch {
				Write-Host -ForegroundColor "Red" $_
			}
			$module = get-module -name $moduleName
			if (-not $module) {
				Write-Host -ForegroundColor "red" $_
				# Weird it's not installable from the central repo
				Write-Host -ForegroundColor "Yellow" "Trying to find module $moduleName anyway!!"
				try {
					find-Module -name $moduleName
				} catch {
					Write-Host -ForegroundColor "Red" $_
				}
				if ($downloadUrl){
					Write-Host -ForegroundColor "Yellow" "Try downloading from $downloadUrl"
				}
				throw "Importing module $moduleName failed."
			}
		}
	}
}

function SharepointWebSessionFromCurrentContext() {
	# Retrieve the client credentials and the related Authentication Cookies
	$context = (Get-SPOWeb).Context
	$credentials = $context.Credentials
	$authenticationCookies = $credentials.GetAuthenticationCookie($targetSiteUri, $true)

	# Set the Authentication Cookies and the Accept HTTP Header
	$webSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
	$webSession.Cookies.SetCookies($targetSiteUri, $authenticationCookies)
	$webSession.Headers.Add("Accept", "application/json;odata=verbose")
	
	return $webSession
}

function SharepointPublicCdnUrlForOrigin($sharepointSiteUrl, $publicCdnOrigin){
	#$result = Invoke-RestMethod "$SharepointSiteUrl/_vti_bin/publiccdn.ashx/url?itemurl=$publicCdnOrigin/placeholder/placeholderAsset.js"
	$result = InvokeRestMethod "$SharepointSiteUrl/_vti_bin/publiccdn.ashx/url?itemurl=$publicCdnOrigin/placeholder/placeholderAsset.js"
	Write-Host -ForegroundColor "Green" "Public CDN url is $result"
}

ImportModuleIfExists "Microsoft.Online.Sharepoint.Powershell" "https://www.microsoft.com/en-ca/download/details.aspx?id=35588"
ImportModuleIfExists "Lapointe.SharePointOnline.PowerShell" "https://github.com/glapointe/PowerShell-SPOCmdlets"
$cdnLibraryUrl = "$SharepointSiteUrl/$CdnOriginLibraryRelativePath"
$existingCdnOrigin = SharepointPublicCdnOriginExistsForLibrary $cdnLibraryUrl
if (-Not $existingCdnOrigin) {
	Write-Host -ForegroundColor "DarkYellow" "Missing public cdn origin library $publicCdnLibraryUrl"
	New-SPOPublicCdnOrigin $cdnLibraryUrl
} else {
	Write-Host -ForegroundColor "Yellow" "CDN public origin exists!"
	$existingCdnOrigin
}

SharepointPublicCdnUrlForOrigin $SharepointSiteUrl $cdnLibraryUrl