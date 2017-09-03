[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True,Position=1,ValueFromPipelineByPropertyName=$true)]
	[string]$ResourceGroupName,

	[Parameter(Mandatory=$True,Position=5,ValueFromPipelineByPropertyName=$true)]
	[string]$sshPublicKey
)

$rmVmssList = Get-AzureRmVmss -ResourceGroupName $ResourceGroupName
foreach ($rmVmss in $rmVmssList) {
    Add-AzureRmVmssSshPublicKey -VirtualMachineScaleSet $rmVmss -KeyData $sshPublicKey
}

