[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True,Position=1,ValueFromPipelineByPropertyName=$true)]
	[string]$ResourceGroupName,

	[Parameter(Mandatory=$True,Position=2,ValueFromPipelineByPropertyName=$true)]
	[string]$SshPublicKey
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

<#
.SYNOPSIS
    .
.DESCRIPTION
    .
.PARAMETER scriptBlock
    The script block will be invoked with a resource group name parameter.
.EXAMPLE
    <Description of example>
.NOTES
#>
function UpdateResourceGroup {
	Param(
		[Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
		[string]$resourceGroupName,

        [Parameter(Mandatory=$True, Position=3, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$true)]
        [System.Management.Automation.ScriptBlock]$scriptBlock
    )
    try {
        Get-AzureRmResourceGroup -Name $resourceGroupName
        & $scriptBlock $resourceGroupName
    } catch [System.Management.Automation.PSInvalidOperationException] {
        if ($_.Exception.Message -Match ".*Login-AzureRmAccount.*") {
            if (LoginAttempt -eq $null) {
                // terminate 
                Write-Error $_
            }
        } else {
            Write-Error $_
        }
    } catch [Exception] {
        if ($_.Exception.Message -Match ".*(ResourceGroupNotFound|resource group does not exist).*") {
            Write-Output "Resource group '$resourceGroupName' not found."
        } else {
			Write-Error $_
		}
    }
}
function UpdateResourceGroupVirtualMachineScaleSets {
    Param(
		[parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
		[string]$resourceGroupName,

	    [Parameter(Mandatory=$True,Position=2, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
	    [string]$sshPublicKey
    )
    $rmVmssList = Get-AzureRmVmss -ResourceGroupName $resourceGroupName
    foreach ($rmVmss in $rmVmssList) {
        $scaleSetId = $rmVmss.Id
        Add-AzureRmVmssSshPublicKey -VirtualMachineScaleSet $rmVmss -KeyData $sshPublicKey
        Write-Host -ForegroundColor "Yellow" "Finished setting SSH key for VM set '$scaleSetId'"
    }
}
function CurryUpdateResourceGroupVirtualMachineScaleSetsClosure {
    Param(
	    [Parameter(Mandatory=$True,Position=2, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
	    [string]$sshPublicKey
    )

    return {
        Param(
		    [parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
		    [string]$resourceGroupName
        )
        UpdateResourceGroupVirtualMachineScaleSets $resourceGroupName $sshPublicKey
    }.GetNewClosure()
}

#Main loop
while ($resourceGroupName) {
    Write-Host -ForegroundColor "Yellow" "Processing resource group '$resourceGroupName'"
    $updateSshKeyClosure = CurryUpdateResourceGroupVirtualMachineScaleSetsClosure $SshPublicKey
    UpdateResourceGroup $ResourceGroupName $updateSshKeyClosure
    Write-Host -ForegroundColor "Yellow" "Finished processing resource group '$resourceGroupName'"
    $resourceGroupName = PromptedResourceGroupName
}


