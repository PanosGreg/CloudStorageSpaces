
$Scriptblock = {
param (
    [string]$VolumeName,      # <-- this will be used in the Storage Pool Name, Drive Label, Disk Name
    [int]$Columns,
    [int[]]$LUNs
)

#region ----------------------- 1) Load the functions
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

function Get-StorageSpace ([string]$Name) {

$VDisk     = Get-VirtualDisk -FriendlyName $Name
$Disk      = Get-Disk -FriendlyName $Name
$Partition = $Disk | Get-Partition | where Type -eq 'Basic'
$Volume    = Get-Volume -Partition $Partition
$AllDisks  = Get-PhysicalDisk -StoragePool (Get-StoragePool -FriendlyName $Name)
$PDisks    = foreach ($PDisk in $AllDisks) {
                $PDisk.PhysicalLocation -match '\d+(?!(LUN))$' | Out-Null
                $Matches.GetEnumerator() | foreach {$CurrentLun = [int]$_.value}
                [PSCustomObject]@{
                    FriendlyName = $PDisk.FriendlyName
                    Size         = $PDisk.Size
                    MediaType    = $PDisk.MediaType
                    LUN          = $CurrentLun
                }
                }

$obj = [pscustomobject] @{
    Date               = Get-Date -Format 'dd/MM/yy HH:mm:ss'
    ComputerName       = $env:COMPUTERNAME
    DriveLetter        = $Partition.DriveLetter
    DriveSize          = $Partition.Size
    FileSystem         = $Volume.FileSystem
    ResiliencySetting  = $VDisk.ResiliencySettingName
    NumberOfColumns    = $VDisk.NumberOfColumns
    NumberofDisks      = $Disks.Count
    PhysicalDisks      = $PDisks
}
Write-Output $obj
}

function Remove-StorageSpace ([string]$Name) {
    Get-VirtualDisk -FriendlyName $Name | Remove-VirtualDisk -Confirm:$false
    Get-StoragePool -FriendlyName $Name | Remove-StoragePool -Confirm:$false
}

Function ConvertTo-Base64 {
<#
.SYNOPSIS
    It transforms a PS object or a String into a Base64 encoded string
#>

[OutputType([String])]
[CmdletBinding(DefaultParameterSetName='PSObject')]
param (
    [Parameter(ParameterSetName='PSObject',Position=0)]
    [object]$InputObject,

    [Parameter(ParameterSetName='String',Position=0)]
    [string]$InputString
)

if ($psCmdlet.ParameterSetName -eq 'PSObject') {
    $InputString = [management.automation.psserializer]::Serialize($InputObject)
}

$ms     = New-Object System.IO.MemoryStream
$mode   = [System.IO.Compression.CompressionMode]::Compress
$gz     = New-Object System.IO.Compression.GZipStream($ms, $mode)
$sw     = New-Object System.IO.StreamWriter($gz)
$sw.Write($InputString)
$sw.Close()
$bytes  = $ms.ToArray()
$OutStr = [System.Convert]::ToBase64String($bytes)
$ms.Close()
$gz.Close()

Write-Output $OutStr

} #function
    
#endregion


#region ----------------------- 2) Create the space & send output
$ProgressPreference = 'SilentlyContinue'
Create-StorageSpace -NumberOfColumns $Columns -Name $VolumeName -Lun $LUNs
$obj = Get-StorageSpace -Name $VolumeName
$out = ConvertTo-Base64 -InputObject $obj
Write-Output $out
#endregion

} # scriptblock

Write-Output $Scriptblock

# Meeded input parameters for Storage Spaces:
# Get    => VolumeName
# Remove => VolumeName
# Expand => VolumeName, LUNs
# Create => VolumeName, LUNs, Columns

# Needed input parameters for Azure:
# - Resource Group
# - VM Name

# functions:
New-StorageVMDisk    # <-- create
Get-StorageVMDisk    # <-- get
Expand-StorageVMDisk # <-- expand
Remove-StorageVMDisk # <-- remove

# Invoke process
# 1 Assemble script   <-- this is the only part that changes depending on the action
# 2 create temp file   |
# 3 run file remotely  | --\ these will be
# 4 delete temp file   | --/ a single helper function
# 5 show results       |

# Remote Scriptblock - Various Parts:
# 1 Common functions: Get-DiskFromLun, Get-StorageSpace, ConvertTo-Base64
# 2 Action function:  Only one from these: Create-StorageSpace | Expand-StorageSpace | Remove-StorageSpace
# 3 Action block:     A specific small block for each action (Create|Expand|Get|Remove) [the main function]

# Files:
# 1 file:  CommonFunctions
# 3 files: Create|Expand|Remove -StorageSpace
# 4 files: New- Create|Expand|Remove|Get -Process  => actually put this code into the function itself, 


# Expand-StorageSpace -Lun 12,13 -Name $Name
# Expand-StorageSpace -Lun 14,15,16,17 -Name $Name



<# NOTES about Virtual Disk Size
The initial pool needs 4GB of spare space
then add an extra 1GB per additional disk (it seems to be 0.5GB per disk, but I add 1gb for safety)

so for example:
initial v.disk = max size (fortunately there's the max size option)
each expand    =  pool.size - (4gb + 1gb/disk in pool)

#>