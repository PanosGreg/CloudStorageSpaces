function Expand-StorageVMDisk {
<#
.SYNOPSIS
    It expands the Simple Storage Spaces disk in an Azure VM

.EXAMPLE
    $params = @{
        ResourceGroup = 'test12'
        VMName        = 'test12-vm1'
    }
    $obj = Get-StorageVMDisk @params
    $LUN = ($obj.PhysicalDisks | where InStorageSpace -eq $false).Lun -join ','
    Expand-StorageVMDisk @params -VolumeName $obj.DriveName -LUNs $LUN
#>

[CmdletBinding()]
param (
    [string]$ResourceGroup,
    [string]$VMName,
    [string]$VolumeName,
    [string]$LUNs     # <-- this is comma separated numbers as a string, ex. "10,11,12"
)

$File = Write-RemoteScript -Action 'Expand'

$params = @{
    ResourceGroupName = $ResourceGroup
    VMName            = $VMName
    CommandId         = 'RunPowerShellScript'
    ScriptPath        = $File
    Parameter         = @{VolumeName=$VolumeName;LUNs=$LUNs}
}
Write-Verbose 'Running remote command...'
$Result  = Invoke-AzVMRunCommand @params
$StdOut  = $Result.Value.Message[0]
$StdErr  = $Result.Value.Message[1]

if ([bool]$StdOut) {$obj = ConvertFrom-Base64 -InputString $StdOut}
if ([bool]$StdErr) {Write-Error $StdErr}
Remove-Item $File

Write-Output $obj

}