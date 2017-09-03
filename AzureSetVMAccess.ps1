[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True,Position=1,ValueFromPipelineByPropertyName=$true)]
	[string]$ResourceGroupName,

	[Parameter(Mandatory=$True,Position=2,ValueFromPipelineByPropertyName=$true)]
	[string]$VirtualMachineSetName,

	[Parameter(Mandatory=$True,Position=3,ValueFromPipelineByPropertyName=$true)]
	[string]$Location, 
	
	[Parameter(Mandatory=$True,Position=4,ValueFromPipelineByPropertyName=$true)]
	[boolean]$reset_ssh,
	
	[Parameter(Mandatory=$True,Position=5,ValueFromPipelineByPropertyName=$true)]
    [AllowEmptyString()]
	[string]$ssh_key,

	[Parameter(Mandatory=$True,Position=6,ValueFromPipelineByPropertyName=$true)]
    [AllowEmptyString()]
	[string]$username,

	[Parameter(Mandatory=$True,Position=7,ValueFromPipelineByPropertyName=$true)]
    [AllowEmptyString()]
	[string]$password,
	
	[Parameter(Mandatory=$True,Position=8,ValueFromPipelineByPropertyName=$true)]
    [AllowEmptyString()]
	[string]$remove_user

)

function SelectAzureRmSubcription() {
	$selection = @()
	$selection += Get-AzureRmSubscription

	If($selection.Count -gt 1){
		$title = "Azure Resource Manager Subscription Selection"
		$message = "Which subscription would you like to use?"

		# Build the choices menu
		$choices = @()
		For($index = 0; $index -lt $selection.Count; $index++){
			$choices += New-Object System.Management.Automation.Host.ChoiceDescription ($selection[$index]).SubscriptionName, ($selection[$index]).SubscriptionId
		}

		$options = [System.Management.Automation.Host.ChoiceDescription[]]$choices
		$result = $host.ui.PromptForChoice($title, $message, $options, 0) 

		$selection = $selection[$result]
	}

	return $selection
}

function SelectVmsFromSet {
	Param(
		[parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
		[String]
		$resourceGroupName,
		
		[parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
		[String]
		$vmScaleSetName
    )
	
	$selection = @()
	$selection += Get-AzureRmVmssVM -ResourceGroupName $resourceGroupName -VMScaleSetName $vmScaleSetName
	
	If($selection.Count -gt 1){
		$title = "Azure VM Selection from VM Set $vmScaleSetName"
		$message = "Which VM would you like to use?"

		# Build the choices menu
		$choices = [System.Management.Automation.Host.ChoiceDescription[]] @()
		For($index = 0; $index -lt $selection.Count; $index++){
			$choices += New-Object System.Management.Automation.Host.ChoiceDescription ($selection[$index]).Name, ($selection[$index]).Id
		}
		$choices += New-Object System.Management.Automation.Host.ChoiceDescription ("All", "All VM's in VM Scale Set $vmScaleSetName")
        $choiceAll = $choices.Count - 1
		$result = $host.ui.PromptForChoice($title, $message, $choices, $choiceAll) 

		if ($result -ne $choiceAll) {
			
			$selection = [array]$selection[$result]
		}
	}
	return $selection
}

$confirmation = Read-Host "Do you want to login to your Azure Resource Manager account?"
if ($confirmation -eq 'y') {
  Login-AzureRmAccount
}

# Determine VM's/scope of change
Get-AzureRmSubscription
$selectedSubscription = SelectAzureRmSubcription
Select-AzureRmSubscription -subscriptionid $selectedSubscription.SubscriptionId
$selectedVms = SelectVmsFromSet $ResourceGroupName $VirtualMachineSetName
Write-Output $selectedVms

# Prepare settings
$PrivateConf = @{username=$username; password=$password; ssh_key=$ssh_key; reset_ssh=$reset_ssh; remove_user=$remove_user}
$ExtensionName = 'VMAccessForLinux'
$Publisher = 'Microsoft.OSTCExtensions'
$Version = '1.*'
Write-Output "Setting $ExtensionName for VM's to `n $PrivateConf"

$selectedVmNames = $selectedVms | foreach-object  -MemberName Name
Write-Output $selectedVmNames

foreach($vmName in $selectedVmNames) {
    Set-AzureRmVMExtension -ResourceGroupName $ResourceGroupName -VMName $vmName -Location $Location -Name $ExtensionName -Publisher $Publisher -ExtensionType $ExtensionName -TypeHandlerVersion $Version -ProtectedSettings $PrivateConf
}
