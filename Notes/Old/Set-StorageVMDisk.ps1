function Set-StorageVMDisk {
<#
.SYNOPSIS
    It configures the empty disks of the Azure VM into a storage spaces volume
.DESCRIPTION
    This process does the following:
    - it runs a remote command on the azure vm
    - this command is a script which creates a storage spaces drive from the available empty drives
      - it creates a storage spaces pool
      - it then creates a virtual disk from that pool
      - it creates a partition in that virtual disk
      - it formats the partition and assigns a drive letter to it
      - it then collects some info about the newly created drive and sends that as the output of this script
      - it collects info about the partition created, the storage spaces virtual disk, the storage spaces pool
        and the physical disks that are part of this pool
    - it then outputs a ps object with all the collected info
      - it serializes this object into xml, it compresses that xml string and finally encodes it with base64
      - on the other end it receives the output and turns it into a ps object
      - when the command finishes, it collects this base64 string
      - it decodes it with base64, it decompresses it and then it deserializes it into a ps object
    Note: the reason why I opted to compress the output is because the Invoke-AzVmRunCommand can send
            an output of up to 4096 bytes, which is pretty limiting. Hence the need to compress the text
    Note: the reason I opted to convert the data into xml is because the Invoke-AzVmRunCommand only
            returns a plain string. So in order to have a ps object as output, I had to serialize and then
            deserialize the data.
.EXAMPLE
    $obj    = terraform output -state=".\disk_expand.tfstate" -json | ConvertFrom-Json
    $VM     = $obj.vm_details.value
    $Script = Remove-Comments -Scriptblock $(.\Remote_Scriptblock.ps1)
    Set-DisksInVM -ResourceGroup $VM.ResGroup -VMName $VM.Name -Script $Script
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [string]$VMName,

    [ValidateSet('SetupVolume','ExpandVolume')]
    [string]$Action = 'SetupVolume',

    [int]$NumberOfColumns = 2   # <-- the number of columns in the storage spaces configuration
)

# dot source any required functions
'Write-RemoteScriptblock','Remove-Comments','ConvertFrom-Base64' | foreach {. "$PSScriptRoot\$_.ps1"}

# create a script file
$Random = ([guid]::NewGuid().Guid).Substring(0,8)
$File   = Join-Path $env:TEMP "$Random.ps1"
$Block  = Write-RemoteScriptblock -Action $Action
$Text   = Remove-Comments -Scriptblock $Block
Set-Content -Path $File -Value $Text

# then run the remote command
$params = @{
    ResourceGroupName = $ResourceGroup
    VMName            = $VMName
    CommandId         = 'RunPowerShellScript'
    ScriptPath        = $File
    OutVariable       = 'cmd'
    Parameter         = @{Name='TestData';NumberOfColumns=$NumberOfColumns}
}
$InStr  = (Invoke-AzVMRunCommand @params).Value.Message[0]
$obj    = ConvertFrom-Base64 -InputString $InStr
Remove-Item $File
Write-Output $obj

} #function

