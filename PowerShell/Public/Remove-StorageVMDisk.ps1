function Remove-StorageVMDisk {
<#
.SYNOPSIS
    It deletes the Simple Storage Spaces disk in an Azure VM
#>

[CmdletBinding()]
param (
    [string]$ResourceGroup,
    [string]$VMName,
    [string]$VolumeName
)

$File = Write-RemoteScript -Action 'Remove'

$params = @{
    ResourceGroupName = $ResourceGroup
    VMName            = $VMName
    CommandId         = 'RunPowerShellScript'
    ScriptPath        = $File
    Parameter         = @{VolumeName=$VolumeName}
}
$InStr  = (Invoke-AzVMRunCommand @params).Value.Message[0]
$obj    = ConvertFrom-Base64 -InputString $InStr
Remove-Item $File

Write-Output $obj

}