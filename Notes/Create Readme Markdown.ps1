
# this is the readme.md markdown file for the module

$Name       = 'InstallWindowsApps'
$FolderRoot = "C:\Code\$Name\Module"
$readme = @"
### Summary
This is the PowerShell module for installing Windows applications silently.

### Version History
* 0.1 Initial Release

### [Version History](https://github.com/PowerShell/PowerShell/releases)

### Installation/Usage
---
[PowerShell v5.1](https://www.microsoft.com/en-us/download/details.aspx?id=54616) is required
``````PowerShell
Import-Module $Name
``````

#### [ToDo]
* Loads...
"@

try {
    Set-Content -Path "$FolderRoot\Readme.md" -Value $readme -ErrorAction Stop
    Write-Warning "[INFO]::Readme markdown file (.md) has been created"
}
catch {
    Write-Warning "[ERROR]::Couldn't create .md file"
    Break
}
