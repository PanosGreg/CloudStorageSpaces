
if (-not [bool](Get-InstalledModule -Name az -ea 0)) {
    Install-Module -Name Az -Repository PSGallery -Scope CurrentUser -AcceptLicense -Force -Confirm:$false
}

Import-Module AzureTF,Az.Accounts

Connect-AzAccount -Credential (Get-Credential)

Install-Terraform
Install-TerraformProvider -Name azure,random

$TfPath  = 'C:\Code\AzureTF\Terraform'
$TfInput = 'C:\Code\AzureTF\Terraform\input.tfvars'
$TfState = 'C:\Code\AzureTF\Terraform\azurevm.tfstate'
$TfPlan  = 'C:\Code\AzureTF\Terraform\azurevm.plan'
New-StorageVM -TfPath $TfPath -TfInput $TfInput -TfState $TfState -TfPlan $TfPlan

$VM = Get-StorageVM -TfState $TfState

$Disk = Set-StorageVMDisk -ResourceGroup $VM.ResGroup -VMName $VM.Name -Action SetupVolume

$Disk = Set-StorageVMDisk -ResourceGroup $VM.ResGroup -VMName $VM.Name -Action ExpandVolume

# alternatively

Initialize-StorageVMDisk -ResourceGroup $VM.ResGroup -VMName $VM.Name

Get-StorageVMDisk -ResourceGroup $VM.ResGroup -VMName $VM.Name  # <-- get how many columns, how many copies, what kind of disks, what size of disks

Expand-StorageVMDisk -ResourceGroup $VM.ResGroup -VMName $VM.Name -TargetCapacity 12TB 
    # target cap. in absolute numberin TB, could've done it with percentage as well


# I like the 2nd option better

Write-Output $Disk
