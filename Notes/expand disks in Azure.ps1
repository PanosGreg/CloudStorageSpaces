

## Expand disks in Azure VM


$TfOut # <-- this came from the terraform output, which has the res.grp, vm name, data disk names

# first shut the vm, but do not de-allocate it (no need)
Stop-AzVM -ResourceGroupName $TfOut.ResGroup -Name $TfOut.Name -Force -StayProvisioned | Out-Null

# then get the VM object
$VM = Get-AzVM -ResourceGroupName $TfOut.ResGroup -Name $TfOut.Name

# detach the disks from the VM
Remove-AzVMDataDisk -VM $VM -DataDiskNames $TfOut.DiskNames | Out-Null

# update the VM's state
Update-AzVM -VM $VM -ResourceGroupName $TfOut.ResGroup | Out-Null

# increase the size of the disks
foreach ($Name in $DiskNames) {
    $Disk = Get-AzDisk -ResourceGroupName $TfOut.ResGroup -DiskName $Name
    $Disk.DiskSizeGB = $Disk.DiskSizeGB * 2
    Update-AzDisk -ResourceGroupName $TfOut.ResGroup -DiskName $Name -Disk $Disk | Out-Null
}

# now re-attach the disks back to the VM
foreach ($Name in $DiskNames) {
    $VM   = Get-AzVM -ResourceGroupName $TfOut.ResGroup -Name $TfOut.Name
    $Disk = Get-AzDisk -ResourceGroupName $TfOut.ResGroup -DiskName $Name
    $params = @{
        CreateOption  = 'Attach'
        Lun           = $DiskNames.IndexOf($Name)
        VM            = $VM
        ManagedDiskId = $Disk.Id
        Caching       = 'ReadWrite'
    }
    $VM = Add-AzVMDataDisk @params
    Update-AzVM -VM $VM -ResourceGroupName $TfOut.ResGroup | Out-Null
}

# finally start the VM
Start-AzVM -ResourceGroupName $TfOut.ResGroup -Name $TfOut.Name | Out-Null

# create 2 new disks
$params = @{
    SkuName      = 'StandardSSD_LRS'
    OsType       = 'Windows'
    DiskSizeGB   = 16
    Location     = 'North Europe'
    CreateOption = 'Empty'
}
$DiskCfg = New-AzDiskConfig @params
'2','3' | foreach {
    $Name = "test12-disk-$_"
    New-AzDisk -ResourceGroupName $TfOut.ResGroup -DiskName $Name -Disk $DiskCfg | Out-Null
}

# attach the new disks to the VM
$NewNames = @(
    [pscustomobject] @{Name = 'test12-disk-2' ; Lun = 2}
    [pscustomobject] @{Name = 'test12-disk-3' ; Lun = 3}
)

foreach ($Disk in $NewNames) {
    $VM      = Get-AzVM -ResourceGroupName $TfOut.ResGroup -Name $TfOut.Name
    $DiskObj = Get-AzDisk -ResourceGroupName $TfOut.ResGroup -DiskName $Disk.Name
    $params = @{
        CreateOption  = 'Attach'
        Lun           = $Disk.Lun
        VM            = $VM
        ManagedDiskId = $DiskObj.Id
        Caching       = 'ReadWrite'
    }
    $VM = Add-AzVMDataDisk @params
    Update-AzVM -VM $VM -ResourceGroupName $TfOut.ResGroup | Out-Null
}

# next steps:
# - add the disks to the storage pool
# - expand the size of the virtual disk
# - expand the size of the partition
# you're done!
