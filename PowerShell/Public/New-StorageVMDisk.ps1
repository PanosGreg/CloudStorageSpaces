function New-StorageVMDisk {
<#
.SYNOPSIS
    It creates a new Simple Storage Spaces disk in an Azure VM
.EXAMPLE
    $param = @{
        ResourceGroup = 'test12'
        VMName        = 'test12-vm1'
        VolumeName    = 'TestData'
        LUNs          = '0,1'
        Columns       = 2
    }
    New-StorageVMDisk @params
#>

[CmdletBinding()]
param (
    [string]$ResourceGroup,
    [string]$VMName,
    [string]$VolumeName,
    [string]$LUNs,     # <-- this is comma separated numbers as a string, ex. "10,11,12"
    [string]$Columns   # <-- number of columns as a string, ex. "2"
)

$File = Write-RemoteScript -Action 'Create'

$params = @{
    ResourceGroupName = $ResourceGroup
    VMName            = $VMName
    CommandId         = 'RunPowerShellScript'
    ScriptPath        = $File
    Parameter         = @{VolumeName=$VolumeName;Columns=$Columns;LUNs=$LUNs}
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