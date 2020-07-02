function Expand-StorageSpace {
<#
.SYNOPSIS
    Expand Storage Spaces Virtual Disk with selected disks
    from specified LUN locations.
#>
param (
    [int[]]$Lun,    # <-- the disks in these LUNs to add in the pool
    [int]$Adapter,  # <-- the SCSI adapter number where the LUNs belong to
    [string]$Name  # <-- the name of the pool/virt.disk
)
$PDiskToAdd = $Lun | foreach {Get-DiskFromLun -Lun $_ -Adapter $Adapter}
$PDiskToAdd | Set-PhysicalDisk -MediaType SSD
Add-PhysicalDisk -StoragePoolFriendlyName $Name -PhysicalDisks $PDiskToAdd
$PDisks  = Get-PhysicalDisk -VirtualDisk (Get-VirtualDisk -FriendlyName $Name)
$NewSize = (Get-StoragePool -FriendlyName $Name).Size - (4GB + 1GB*$PDisks.Count)
Resize-VirtualDisk -FriendlyName $Name -Size $NewSize
$Volume  = Get-VirtualDisk -FriendlyName $Name | Get-Disk | Get-Partition | Get-Volume
$NewPartSize = (Get-PartitionSupportedSize -DriveLetter $Volume.DriveLetter).SizeMax
Resize-Partition -DriveLetter $Volume.DriveLetter -Size $NewPartSize
}
