
$ProgressPreference = 'SilentlyContinue'
Get-PhysicalDisk | where DeviceId -ge 2 | Set-PhysicalDisk -MediaType SSD
$Name = 'TestData'
$Param_Pool = @{
    FriendlyName             = $Name
    StorageSubSystemUniqueId = (Get-StorageSubSystem).UniqueId
    PhysicalDisks            = Get-PhysicalDisk -CanPool:$true
}
$Pool = New-StoragePool @Param_Pool
$Param_VDisk = @{
    StoragePoolFriendlyName = $Name
    FriendlyName            = $Name
    ResiliencySettingName   = "Mirror"
    ProvisioningType        = 'Fixed'
    MediaType               = 'SSD'
    UseMaximumSize          = $true
    NumberOfDataCopies      = 2
    NumberOfColumns         = 2
}
$Vdisk = New-VirtualDisk @Param_VDisk
Initialize-Disk -FriendlyName $Name
$DiskNumber = (Get-Disk -FriendlyName $Name).Number
$GptType    = "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
New-Partition -DiskNumber $DiskNumber -UseMaximumSize -GptType $GptType | Out-Null
$Partition  = (Get-Partition -DiskNumber $DiskNumber | Sort-Object Size -Descending)[0]
Format-Volume -Partition $Partition -FileSystem ReFS -NewFileSystemLabel $Name | Out-Null
Add-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $Partition.PartitionNumber -AssignDriveLetter
$Partition  = (Get-Partition -DiskNumber $DiskNumber | Sort-Object Size -Descending)[0]
$DiskProperties = 'FriendlyName,Size,MediaType,DeviceId,PhysicalLocation'.Split(',')
$Disks = Get-PhysicalDisk -StoragePool $Pool | select $DiskProperties
$obj = [pscustomobject] @{
    DriveLetter        = $Partition.DriveLetter
    DriveSize          = $Partition.Size
    NumberOfColumns    = $Vdisk.NumberOfDataCopies 
    NumberOfDataCopies = $Vdisk.NumberOfDataCopies
    NumberofDisks      = $Disks.Count
    PhysicalDisks      = $Disks
}

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
Write-Output $out

