#Get public and private functions
    $Public  = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
    $Private = Join-Path -Path $PSScriptRoot -ChildPath 'Private'
    $params     = @{
        Filter      = '*.ps1'
        Recurse     = $true
        File        = $true
        ErrorAction = 'SilentlyContinue'
    }
    $Public  = @(Get-ChildItem $Public  @params)
    $Private = @(Get-ChildItem $Private @params | Where PSPath -NotLike '*Private/RemoteOnly*')

#Dot source the files
    Foreach($import in @($Public+$Private))
    {
        Try
        {
            . $import.FullName
        }
        Catch
        {
            Write-Error -Message "Failed to import function $($import.fullname): $_"
        }
    }

<#
#Get C# files and compiled libraries
    $CSharpFiles = Get-ChildItem $Private '*.cs'


#Load the Classes & Enumerations
    Foreach ($file in $CSharpFiles)
    {
        Try
        {
            Add-Type -Path $file.FullName -ErrorAction Stop
        }
        Catch
        {
            Write-Error -Message "Failed to import types from $($file.FullName): $_"
        }

    }
#>
