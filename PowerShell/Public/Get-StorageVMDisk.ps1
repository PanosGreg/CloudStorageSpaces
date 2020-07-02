function Get-StorageVMDisk {
<#
.SYNOPSIS
    It gives details of the Simple Storage Spaces disk in an Azure VM
#>

[CmdletBinding()]
param (
    [string]$ResourceGroup,
    [string]$VMName,
    [switch]$IncludeAzureData
)

$File = Write-RemoteScript -Action 'Get'

$params = @{
    ResourceGroupName = $ResourceGroup
    VMName            = $VMName
    CommandId         = 'RunPowerShellScript'
    ScriptPath        = $File
}
Write-Verbose 'Running remote command...'
$Result  = Invoke-AzVMRunCommand @params  # <-- Output Limit is 4096 bytes
$StdOut  = $Result.Value.Message[0]
$StdErr  = $Result.Value.Message[1]
Remove-Item $File

if ([bool]$StdOut) {$obj = ConvertFrom-Base64 -InputString $StdOut}  # <-- use -Verbose to see the compressed sizes
if ([bool]$StdErr) {Write-Error $StdErr}

if ($IncludeAzureData) {
    Write-Verbose 'Getting data from Azure...'
    $DisksInSS = $obj.PhysicalDisks | where InStorageSpace -eq $true
    $VM        = Get-AzVM -ResourceGroupName $ResourceGroup -Name $VMName  # <-- all disks in VM from Azure
    $Disks     = $VM.StorageProfile.DataDisks #  <-- these are all DATA disks, which are in Adapter 1
    $AzDisks   = foreach ($Disk in $Disks) {
                    foreach ($VmDisk in $DisksInSS) {
                        if ($Disk.Lun -eq $VmDisk.Lun) {
                            $DskObj = Get-AzDisk -Name $Disk.Name
                            [PSCustomObject] @{
                                DiskSizeGB = $Disk.DiskSizeGB
                                Location   = $DskObj.Location
                                SkuName    = $DskObj.Sku.Name
                            } #psobject output
                        } #if external lun is eq. to internal lun
                    } #foreach disk in storage spaces pool
                } #foreach disk attached to the VM
    $DataDisk = [PSCustomObject] @{
        Prefix     = $VM.Name
        SkuName    = $AzDisks[0].SkuName
        DiskSizeGB = $AzDisks[0].DiskSizeGB
        Location   = $AzDisks[0].Location
    }
    $VMSize       = $VM.HardwareProfile.VmSize
    $MaxDiskCount = (Get-AzVMSize -Location $vm.Location | where Name -eq $VMSize).MaxDataDiskCount
    $obj | Add-Member -MemberType NoteProperty -Name MaxDiskCount    -Value $MaxDiskCount
    $obj | Add-Member -MemberType NoteProperty -Name InUseDiskCount  -Value $Disks.Count
    $obj | Add-Member -MemberType NoteProperty -Name FreeDiskCount   -Value ($MaxDiskCount - $Disks.Count)
    $obj | Add-Member -MemberType NoteProperty -Name DefaultDataDisk -Value $DataDisk  
} #if IncludeAzureData switch

Write-Output $obj

}