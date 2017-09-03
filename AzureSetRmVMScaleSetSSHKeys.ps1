[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True,Position=1,ValueFromPipelineByPropertyName=$true)]
	[string]$ResourceGroupName,

	[Parameter(Mandatory=$True,Position=2,ValueFromPipelineByPropertyName=$true)]
	[string]$SshPublicKey, 

    [Parameter(Mandatory=$False, Position=3, ValueFromPipelineByPropertyName=$true)]
    [boolean]$promptToLogin = $True
)
$ErrorActionPreference = ‘Stop’

function LoginAttempt() {
    $confirmation = Read-Host "Do you want to login to your Azure Resource Manager account?"
    if ($confirmation -eq 'y') {
      Login-AzureRmAccount
      return $True
    } 
    return $Null
}

function PromptedResourceGroupName() {
    $value = Read-Host "Enter another Resource Manager Group name or 'q' to quit."
    if ($value -ne 'q' -or $value -eq '') {
      return $value
    } 
    return $Null
}

function SetSshPublicKeys {
	Param(
		[parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true)]
		[String]
		$resourceGroupName,

	    [Parameter(Mandatory=$True,Position=2, ValueFromPipelineByPropertyName=$true)]
	    [string]$sshPublicKey
    )
    while ($resourceGroupName) {
        try {
            $rmVmssList = Get-AzureRmVmss -ResourceGroupName $resourceGroupName
            foreach ($rmVmss in $rmVmssList) {
                Add-AzureRmVmssSshPublicKey -VirtualMachineScaleSet $rmVmss -KeyData $sshPublicKey
            }
            Write-Output "All Resource group '$resourceGroupName' Virtual Machine scale set VM's have been updated."
            $resourceGroupName = PromptedResourceGroupName
        } catch [System.Management.Automation.PSInvalidOperationException] {
            if ($_.Exception.Message -Match ".*Login-AzureRmAccount.*") {
                if (LoginAttempt -eq $null) {
                    // terminate 
                    $resourceGroupName = $null
                }
            }
        } catch [Exception] {
            if ($_.Exception.Message -Match ".*ResourceGroupNotFound.*") {
                Write-Output "Resource group '$resourceGroupName' not found."
                $resourceGroupName = PromptedResourceGroupName
            }
        }
    }
}

SetSshPublicKeys $ResourceGroupName $SshPublicKey

