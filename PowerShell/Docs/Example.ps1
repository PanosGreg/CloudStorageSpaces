

###  Example of the complete process  ###


# load the module
Import-Module C:\Code\AzureTF\PowerShell\AzureStorageSpaces.psd1

# load the TF functions
dir C:\Code\AzureTF\PowerShell\*.ps1 | foreach {. $_}

# create the VM
$TfPath  = 'C:\Code\AzureTF\Terraform\'
$TfInput = 'C:\Code\AzureTF\Terraform\input.tfvars'
$TfPlan  = 'C:\Code\AzureTF\Terraform\azurevm.plan'
New-StorageVM -TfPath $TfPath -TfInput $TfInput -TfPlan $TfPlan


# get the variables
$TfOut  = Get-StorageVM -TfPath $TfPath
$ResGrp = $TfOut.ResGroup
$VMName = $TfOut.Name
$LUNs   = $TfOut.DiskInfo.Lun -join ','


# create the storage space
$params = @{
    ResourceGroup = $ResGrp
    VMName        = $VMName
    LUNs          = $LUNs
    VolumeName    = 'TestData'
    Columns       = 2
}
New-StorageVMDisk @params


# add new disks to VM
Add-StorageVMDisk -ResourceGroup $ResGrp -VMName $VMName


# expand the storage space
$params = @{
    ResourceGroup = $ResGrp
    VMName        = $VMName
}
$obj = Get-StorageVMDisk @params
$LUN = ($obj.PhysicalDisks | where InStorageSpace -eq $false).Lun -join ','
Expand-StorageVMDisk @params -VolumeName $obj.DriveName -LUNs $LUN


# go check the VM
mstsc /v:($TfOut.IpAddress)


# finally delete the VM
Remove-StorageVM -TfPath $TfPath -TfInput $TfInput


# full script for convenience
# (configuration only not provisioning)
$script = {

$params = @{
    ResourceGroup = 'TestResGrp'
    VMName        = 'TestVM'
}
New-StorageVMDisk @params -VolumeName 'TestVol' -LUNs '0,1' -Columns 2

Add-StorageVMDisk @params

$obj = Get-StorageVMDisk @params
$LUN = ($obj.PhysicalDisks | where InStorageSpace -eq $false).Lun -join ','

Expand-StorageVMDisk @params -VolumeName $obj.DriveName -LUNs $LUN

}


## and that's it !!