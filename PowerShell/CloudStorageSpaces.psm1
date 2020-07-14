#Get public and private functions
    $PublicPath  = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
    $PrivatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'
    $params     = @{
        Filter      = '*.ps1'
        Recurse     = $true
        File        = $true
        ErrorAction = 'SilentlyContinue'
    }
    $Public  = Get-ChildItem $PublicPath  @params
    $Private = Get-ChildItem $PrivatePath @params | Where PSPath -NotLike '*Private/RemoteOnly*'

#Dot source the files
    Foreach($import in ($Public+$Private))
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


#Get C# files and compiled libraries
    $CSharpFiles = Get-ChildItem -Path $PrivatePath -Filter '*.cs'

#Load the Classes & Enumerations
    Foreach ($file in $CSharpFiles)
    {
        Try
        {
           #Add-Type -Path $file.FullName -ErrorAction Stop
        }
        Catch
        {
            Write-Error -Message "Failed to import types from $($file.FullName): $_"
        }

    }

