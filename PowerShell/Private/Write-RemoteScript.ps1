function Write-RemoteScript {
<#
.SYNOPSIS
    It will assemble the script that will be run on the remote Azure VM
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateSet('Create','Expand','Get','Remove')]
    [string]$Action,
    [switch]$DontRemoveComments,
    [switch]$OutText    # <-- by default it writes to a file, no other output

)

$sb   = [System.Text.StringBuilder]::new()
$Path = Join-Path $PSScriptRoot RemoteOnly

switch ($Action) {
    'Create' {$ParamsBlock = 'param ([string]$VolumeName,[string]$Columns,[string]$LUNs)'}
    'Expand' {$ParamsBlock = 'param ([string]$VolumeName,[string]$LUNs)'}
    'Remove' {$ParamsBlock = 'param ([string]$VolumeName)'}
    'Get'    {$ParamsBlock = $null}
}
[void]$sb.AppendLine($ParamsBlock)
[void]$sb.AppendLine([System.Environment]::NewLine)
[void]$sb.AppendLine((Get-Content "$Path\CommonFunctions.ps1" -Raw))

switch ($Action) {
    'Create' {$FunctionBlock = Get-Content "$Path\Create-StorageSpace.ps1" -Raw}
    'Expand' {$FunctionBlock = Get-Content "$Path\Expand-StorageSpace.ps1" -Raw}
    default  {$FunctionBlock = $null}
}
[void]$sb.AppendLine($FunctionBlock)

switch ($Action) {
    'Create' {$Conversion = '$Lun =[int[]]($LUNs.Split(",")) ; $Cols=[int]$Columns'}
    'Expand' {$Conversion = '$Lun =[int[]]($LUNs.Split(","))'}
    default  {$Conversion = $null}
}
[void]$sb.AppendLine($Conversion)

[void]$sb.AppendLine('$ProgressPreference = "SilentlyContinue"')
[void]$sb.AppendLine('$Adapter = 1')  # <-- this is the SCSI adapter of the VM, where the LUNs reside
                                      #     in Azure all DATA disks are attached to Adapter 1
                                      #     in local Hyper-V all disks are attached to Adapter 0
                                      #     in AWS (non-NVMe) disks are attached to Adapter 2
switch ($Action) {
    'Create' {$cmd='Create-StorageSpace -NumberOfColumns $Cols -Name $VolumeName -Lun $Lun -Adapter $Adapter'}
    'Expand' {$cmd='Expand-StorageSpace -Name $VolumeName -Lun $Lun -Adapter $Adapter'}
    'Remove' {$cmd='Remove-StorageSpace -Name $VolumeName'}
    'Get'    {$cmd=$null}
}
[void]$sb.AppendLine($cmd)

$OutputBlock = @'
$obj = Get-StorageSpace
$out = ConvertTo-Base64 -InputObject $obj
Write-Output $out
'@
[void]$sb.AppendLine($OutputBlock)

$Text = $sb.ToString()

if ($DontRemoveComments) {$null}
else {
    $Block = [scriptblock]::Create($Text)
    $Text  = Remove-Comments -Scriptblock $Block
}

if ($OutText) {
    Write-Output $Text
}
else {
    $Random = ([guid]::NewGuid().Guid).Substring(0,8)
    $File   = Join-Path $env:TEMP "$Random.ps1"
    Set-Content -Path $File -Value $Text
    Write-Output $File
}
}