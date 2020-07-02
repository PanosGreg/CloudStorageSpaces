function Get-DiskFromLun ([int]$Lun,[int]$Adapter) {
<#
.SYNOPSIS
    Get the physical disk that's located in a specified LUN
    It returns a PhysicalDisk CIM instance
#>
    $PDisks = Get-PhysicalDisk
    foreach ($PDisk in $PDisks) {
        if ($PDisk.PhysicalLocation -like "*Adapter $Adapter*") {
            $PDisk.PhysicalLocation -match '\d+(?!(LUN))$' | Out-Null
            $Matches.GetEnumerator() | foreach {$CurrentLun = [int]$_.value}
            if ($CurrentLun -eq $Lun) {$PDisk} # <-- this is the output
        }
    }
}

function Get-StorageSpace {
<#
.SYNOPSIS
    Return details about the Storage Space
    NOTE: I assume there is only 1 storage space virtual disk in the server
#>
$VDisk = Get-VirtualDisk
if (-not [bool]$VDisk) {
    $out = [PSCustomObject] @{
        ComputerName = $env:COMPUTERNAME
        Result       = 'Could not find any Virtual Disk'
    }
    Return $out
}
$Name = $VDisk.FriendlyName

$Disk      = Get-Disk -FriendlyName $Name
$Partition = $Disk | Get-Partition | where Type -eq 'Basic'
$Volume    = Get-Volume -Partition $Partition
$DisksOn   = Get-PhysicalDisk -StoragePool (Get-StoragePool -FriendlyName $Name)
$DisksOff  = Get-PhysicalDisk -CanPool:$true
$PDisks    = foreach ($PDisk in ($DisksOn,$DisksOff).ForEach({$_})) {
                $PDisk.PhysicalLocation -match '\d+(?!(LUN))$' | Out-Null
                $Matches.GetEnumerator() | foreach {$CurrentLun = [int]$_.value}
                [PSCustomObject]@{
                    FriendlyName    = $PDisk.FriendlyName
                    Size            = $PDisk.Size
                    MediaType       = $PDisk.MediaType
                    LUN             = $CurrentLun
                    InStorageSpace  = -not $PDisk.CanPool
                }
            }

$Chunk = ($PDisks[0].Size * $VDisk.NumberOfColumns) - ($PDisks.Count*1GB)
$obj = [pscustomobject] @{
    Date               = Get-Date -Format 'dd/MM/yy HH:mm:ss'
    ComputerName       = $env:COMPUTERNAME
    DriveName          = $Name
    DriveLetter        = $Partition.DriveLetter
    DriveSize          = $Partition.Size
    ExpansionSizeGB    = [math]::Round($Chunk/1000000000,0)  # <-- amount of capacity increase per one expansion
    FileSystem         = $Volume.FileSystem
    ResiliencySetting  = $VDisk.ResiliencySettingName
    NumberOfColumns    = $VDisk.NumberOfColumns
    NumberofDisks      = $DisksOn.Count
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

$ms     = [System.IO.MemoryStream]::new()
$mode   = [System.IO.Compression.CompressionMode]::Compress
$gz     = [System.IO.Compression.GZipStream]::new($ms, $mode)
$sw     = [System.IO.StreamWriter]::new($gz)
$sw.Write($InputString)
$sw.Close()
$bytes  = $ms.ToArray()
$OutStr = [System.Convert]::ToBase64String($bytes)
$ms.Close()
$gz.Close()

Write-Output $OutStr

}
