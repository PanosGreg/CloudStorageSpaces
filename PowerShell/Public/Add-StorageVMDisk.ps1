function Add-StorageVMDisk {
<#
.SYNOPSIS
    It adds managed disks to an Azure VM

.DESCRIPTION
    This function will get all the data about the disks in the VM
    (both from the OS as well as from Azure)
    And then it will create the appropriate number of disks, that are of 
    the same type,size of those in the storage pool.
    And finally it will attach them to the VM

.EXAMPLE
    Add-StorageVMDisk -ResourceGroup Res1 -VMName VM1
#>

[CmdletBinding()]
param (
    [string]$ResourceGroup,
    [string]$VMName
)

Write-Verbose 'Getting data from VM...'
$VmDisks = Get-StorageVMDisk -ResourceGroup $ResourceGroup -VMName $VMName -IncludeAzureData
$LastLun = ($VmDisks.PhysicalDisks | Measure-Object -Property LUN -Maximum).Maximum
$FromLun = $LastLun + 1
$ToLun   = $LastLun + $VmDisks.NumberOfColumns

#region ------------------ Create the disks
Write-Verbose 'Creating the disks in Azure...'
$params = @{
    SkuName      = $VmDisks.DefaultDataDisk.SkuName
    OsType       = 'Windows'
    DiskSizeGB   = $VmDisks.DefaultDataDisk.DiskSizeGB
    Location     = $VmDisks.DefaultDataDisk.Location
    CreateOption = 'Empty'
}
$DiskCfg = New-AzDiskConfig @params

$NewDisks = $FromLun..$ToLun | foreach {
    $params = @{
        ResourceGroupName = $ResourceGroup
        DiskName          = '{0}-{1}' -f $VmDisks.DefaultDataDisk.Prefix,$_    # <-- the names must have a prefix number which should be the LUN number for clarity and uniqueness
        Disk              = $DiskCfg
    }
    $obj = New-AzDisk @params
    $obj | Add-Member -MemberType NoteProperty -Name Lun -Value $_ -PassThru
}
#endregion 

#region ------------------ Attach the new disks to the VM
Write-Verbose 'Attaching the disks to the VM...'
foreach ($Disk in $NewDisks) {
    $VM     = Get-AzVM -ResourceGroupName $ResourceGroup -Name $VMName
    $params = @{
        CreateOption  = 'Attach'
        Lun           = $Disk.Lun
        VM            = $VM
        ManagedDiskId = $Disk.Id
        Caching       = 'ReadWrite'
    }
    $VM = Add-AzVMDataDisk @params
    Update-AzVM -VM $VM -ResourceGroupName $ResourceGroup | Out-Null
}
#endregion
}