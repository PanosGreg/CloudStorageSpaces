function Write-RemoteScriptblock {
<#
.SYNOPSIS
    It creates a storage spaces volume
.DESCRIPTION
    This is the scriptblock that will be run on the remote Azure VM via
    the Invoke-AzVMRunCommand.
    This script sets up the storage spaces drive on the VM.
    a) it uses the empty (available) disks to creates a storage pool
    b) then it creates a virtual disk from that pool
    c) and finally it creates a partitions from that virtual disk and
       formats the volume.
#>
[cmdletbinding()]
param (
    [ValidateSet('SetupVolume','ExpandVolume')]
    [string]$Action = 'SetupVolume'
)

$SetupVolume = {
param(
    [string]$Name, # <-- this will be used in the Storage Pool Name, Drive Label, Disk Name
    [int]$NumberOfColumns
)
# many of the below commands have a progress bar, this will make them faster
$ProgressPreference = 'SilentlyContinue'

# set all data disks to SSD type, this is important when creating the vdisk
# disks 0 and 1 is the OS and Temp drives
Get-PhysicalDisk | where DeviceId -ge 2 | Set-PhysicalDisk -MediaType SSD

# create the storage pool
$Param_Pool = @{
    FriendlyName             = $Name
    StorageSubSystemUniqueId = (Get-StorageSubSystem).UniqueId
    PhysicalDisks            = Get-PhysicalDisk -CanPool:$true
}
$Pool = New-StoragePool @Param_Pool

# now create the virtual disk
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

# now create a partition
Initialize-Disk -FriendlyName $Name

$DiskNumber = (Get-Disk -FriendlyName $Name).Number
$GptType    = "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"  # <-- this is needed to avoid having windows create unnecessary partitions

New-Partition -DiskNumber $DiskNumber -UseMaximumSize -GptType $GptType | Out-Null
$Partition  = (Get-Partition -DiskNumber $DiskNumber | Sort-Object Size -Descending)[0]

Format-Volume -Partition $Partition -FileSystem ReFS -NewFileSystemLabel $Name | Out-Null
$params = @{
    DiskNumber        = $DiskNumber
    AssignDriveLetter = $true
    PartitionNumber   = $Partition.PartitionNumber 
}
Add-PartitionAccessPath @params

# now collect some data that will be assembled into a psobject
$Partition      = (Get-Partition -DiskNumber $DiskNumber | Sort-Object Size -Descending)[0]
$DiskProperties = 'FriendlyName,Size,MediaType,DeviceId,PhysicalLocation'.Split(',')
$Disks          = Get-PhysicalDisk -StoragePool $Pool | select $DiskProperties
$Volume         = Get-Volume -Partition $Partition

# create the ps object that will be sent back as the output
$obj = [pscustomobject] @{
    ComputerName       = $env:COMPUTERNAME
    DriveLetter        = $Partition.DriveLetter
    DriveSize          = $Partition.Size
    FileSystem         = $volume.FileSystem
    ResiliencySetting  = $vdisk.ResiliencySettingName
    NumberOfDataCopies = $Vdisk.NumberOfDataCopies
    NumberOfColumns    = $Vdisk.NumberOfColumns
    NumberofDisks      = $Disks.Count
    PhysicalDisks      = $Disks
}

# convert the object: serialize it into xml,compress it with gzip, and finally encode it with base64 encoding
$xml    = [System.Management.Automation.Psserializer]::Serialize($obj,3)
$ms     = New-Object System.IO.MemoryStream
$mode   = [System.IO.Compression.CompressionMode]::Compress
$gz     = New-Object System.IO.Compression.GZipStream($ms, $mode)
$sw     = New-Object System.IO.StreamWriter($gz)
$sw.Write($xml)
$sw.Close()
$bytes = $ms.ToArray()
$out   = [System.Convert]::ToBase64String($bytes)
$ms.Close()
$gz.Close()

# finally sent the output
Write-Output $out
}


switch ($Action) {
    'SetupVolume'  {$Scriptblock = $SetupVolume}
    'ExpandVolume' {$Scriptblock = $ExpandVolume}
}
Write-Output $Scriptblock  # <-- this is of [scriptblock] type

}