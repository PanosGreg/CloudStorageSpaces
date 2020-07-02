function Get-DiskFromLun ([int]$Lun) {
<#
.SYNOPSIS
    Get the physical disk that's located in a specified LUN
    It returns a PhysicalDisk CIM instance
#>
    $PDisks = Get-PhysicalDisk
    foreach ($PDisk in $PDisks) {
        $PDisk.PhysicalLocation -match '\d+(?!(LUN))$' | Out-Null
        $Matches.GetEnumerator() | foreach {$CurrentLun = [int]$_.value}
        if ($CurrentLun -eq $Lun) {$PDisk} # <-- this is the output
    }
}

function Create-StorageSpace {
<#
.SYNOPSIS
    Creates a new Simple Storage Space
#>
param (
    [int]$NumberOfColumns,
    [string]$Name,
    [int[]]$Lun
)
$InitialPool = $LUN | foreach {Get-DiskFromLun -Lun $_}
$InitialPool | Set-PhysicalDisk -MediaType 'SSD'

$Param_Pool = @{
    FriendlyName             = $Name
    StorageSubSystemUniqueId = (Get-StorageSubSystem).UniqueId
    PhysicalDisks            = $InitialPool
}
$Pool = New-StoragePool @Param_Pool

$Param_VDisk = @{
    StoragePoolFriendlyName = $Name
    FriendlyName            = $Name
    ResiliencySettingName   = "Simple"  # <-- Simple, Mirror, Parity
    ProvisioningType        = 'Fixed'
    MediaType               = 'SSD'
    UseMaximumSize          = $true
    #NumberOfDataCopies      = 2      # only use this if setting up mirror disk
    NumberOfColumns         = $NumberOfColumns
}
$Vdisk = New-VirtualDisk @Param_VDisk

Initialize-Disk -FriendlyName $Name | Out-Null
$Disk    = Get-Disk -FriendlyName $Name
$GptType = "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
[void](New-Partition -DiskNumber $Disk.Number -UseMaximumSize -GptType $GptType)
$Part    = $Disk | Get-Partition | where Type -eq 'Basic'
[void](Format-Volume -Partition $Part -FileSystem ReFS -NewFileSystemLabel $Name)
$Param_Access = @{
    DiskNumber        = $Disk.Number
    AssignDriveLetter = $true
    PartitionNumber   = $Part.PartitionNumber 
}
Add-PartitionAccessPath @Param_Access
}

function Expand-StorageSpace {
<#
.SYNOPSIS
    Expand Storage Spaces Virtual Disk with selected disks
    from specified LUN locations.
#>
param (
    [int[]]$Lun,   # <-- the disks in these LUNs to add in the pool
    [string]$Name  # <-- the name of the pool/virt.disk
)
$PDiskToAdd = $Lun | foreach {Get-DiskFromLun -Lun $_}
$PDiskToAdd | Set-PhysicalDisk -MediaType SSD
Add-PhysicalDisk -StoragePoolFriendlyName $Name -PhysicalDisks $PDiskToAdd
$PDisks  = Get-PhysicalDisk -VirtualDisk (Get-VirtualDisk -FriendlyName $Name)
$NewSize = (Get-StoragePool -FriendlyName $Name).Size - (4GB + 1GB*$PDisks.Count)
Resize-VirtualDisk -FriendlyName $Name -Size $NewSize
$Volume  = Get-VirtualDisk -FriendlyName $Name | Get-Disk | Get-Partition | Get-Volume
$NewPartSize = (Get-PartitionSupportedSize -DriveLetter $Volume.DriveLetter).SizeMax
Resize-Partition -DriveLetter $Volume.DriveLetter -Size $NewPartSize
}


<# ================================= #>

$Name = 'TestData'

Create-StorageSpace -NumberOfColumns 2 -Name $Name -Lun 10,11

Expand-StorageSpace -Lun 12,13 -Name $Name
Expand-StorageSpace -Lun 14,15,16,17 -Name $Name


# and now delete it
Get-VirtualDisk -FriendlyName $Name | Remove-VirtualDisk -Confirm:$false
Get-StoragePool -FriendlyName $Name | Remove-StoragePool -Confirm:$false


<# NOTES about Virtual Disk Size
The initial pool needs 4GB of spare space
then add an extra 1GB per additional disk (it seems to be 0.5GB per disk, but I add 1gb for safety)

so for example:
initial v.disk = max size (fortunately there's the max size option)
each expand    =  pool.size - (4gb + 1gb/disk in pool)

#>