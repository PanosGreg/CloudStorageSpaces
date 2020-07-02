function Create-ManifestFile ($Name) {

# create the module manifest


$Params_ModMan = @{
    Path                = "$PSScriptRoot\$Name.psd1"
    RootModule          = "$Name.psm1"
    Author              = 'Panos Grigoriadis'
    Description         = 'Create & Expand Storage Spaces in Azure VMs'
    Tags                = 'PowerShell','Azure','Storage Spaces'
    ModuleVersion       = '1.0.0'
    PowerShellVersion   = '5.1'
    RequiredModules     = 'Az.Compute'  # <-- for the Invoke-AzVMRunCommand
    #RequiredAssemblies = ""
    FunctionsToExport   = ''
    CmdletsToExport     = @()
    ReleaseNotes        = 'This module automates the creation and expansion of storage spaces disks used by VMs in Azure'
    #ProjectUri          = 
    #HelpInfoUri         = 
}

try {
    New-ModuleManifest @Params_ModMan -Verbose -ErrorAction Stop 4>$null
    Write-Warning "[INFO]::Module manifest (psd1) has been created"
}
catch {
    Write-Warning "[ERROR]::Couldn't create PSD1 file"
    Break
}

}