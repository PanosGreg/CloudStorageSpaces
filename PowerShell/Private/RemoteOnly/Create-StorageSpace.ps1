function Create-StorageSpace {
<#
.SYNOPSIS
    Creates a new Simple Storage Space
#>
param (
    [int]$NumberOfColumns,
    [string]$Name,
    [int[]]$Lun,
    [int]$Adapter
)
$InitialPool = $LUN | foreach {Get-DiskFromLun -Lun $_ -Adapter $Adapter}
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
