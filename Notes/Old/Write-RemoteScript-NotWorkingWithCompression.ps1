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
    [switch]$OutText,    # <-- by default it writes to a file, no other output
    [switch]$DontCompress
)

$sb   = [System.Text.StringBuilder]::new()
$Path = Join-Path $PSScriptRoot RemoteOnly

switch ($Action) {
    'Create' {$ParamsBlock = 'param ([string]$VolumeName,[int]$Columns,[int[]]$LUNs)'}
    'Expand' {$ParamsBlock = 'param ([string]$VolumeName,[int[]]$LUNs)'}
    'Remove' {$ParamsBlock = 'param ([string]$VolumeName)'}
    'Get'    {$ParamsBlock = 'param ([string]$VolumeName)'}
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

[void]$sb.AppendLine('$ProgressPreference = "SilentlyContinue"')
[void]$sb.AppendLine('$Adapter = 1')  # <-- this is the SCSI adapter of the VM, where the LUNs reside
                                      #     in Azure all DATA disks are attached to Adapter 1
                                      #     in local Hyper-V all disks are attached to Adapter 0
switch ($Action) {
    'Create' {$cmd='Create-StorageSpace -NumberOfColumns $Columns -Name $VolumeName -Lun $LUNs -Adapter $Adapter'}
    'Expand' {$cmd='Expand-StorageSpace -Name $VolumeName -Lun $LUNs -Adapter $Adapter'}
    'Remove' {$cmd='Remove-StorageSpace -Name $VolumeName'}
    'Get'    {$cmd=$null}
}
[void]$sb.AppendLine($cmd)

$OutputBlock = @'
$obj = Get-StorageSpace -Name $VolumeName
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

##  I M P O R T A N  T  ##
## The compression does NOT work because I can't pass the input parameters from Invoke-AzVMRunCommand
## into the encoded sciptblock.
if ($DontCompress) {$null}
else {
    Write-Verbose "Original script length (in bytes): $($Text.Length)"
    $Enc = ConvertTo-Base64 -InputString $Text -Verbose:$false
    $DecompressRemotely = @'
    $Enc  = '<Enc>'
    $data = [System.Convert]::FromBase64String($Enc)
    $ms   = [System.IO.MemoryStream]::new()
    $ms.Write($data, 0, $data.Length)
    $ms.Seek(0,0) | Out-Null
    $mode = [System.IO.Compression.CompressionMode]::Decompress
    $gz   = [System.IO.Compression.GZipStream]::new($ms, $mode)
    $sr   = [System.IO.StreamReader]::new($gz)
    $Str  = $sr.ReadToEnd()
    $sr.Close() ; $ms.Close() ; $gz.Close()
    Invoke-Expression -Command $Str
'@
    $Text = $DecompressRemotely.Replace('<Enc>',$Enc)
    Write-Verbose "Compressed script length (bytes):  $($Text.Length)"
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