Function ConvertFrom-Base64 {

<#
.SYNOPSIS
    It transforms a Base64 string into a PS object or a string

.DESCRIPTION
    This function takes a string that is compressed and also encoded with Base64 encoding.
    Then it decompresses and decodes it, and either outputs a string or if that was
    an XML it outputs a PS Object

    Input:  a base64 string, that's essentially a compressed array of bytes
    Output: a string or a PS object

    Process: it takes a base64 string
             then it decodes it with Base64 encoding
               (which gives back an array of bytes)
             then it creates a memory stream
             then writes the byte array into the memory stream
             then it moves the pointer back to the start of the memory stream
             then it wraps the memory stream on a decompression stream
             then it wraps the decompression stream on a reader stream
             then it reads the streamreader
               (which reads it from the beginning since the pointer was reset earlier)
               (which decompresses the data as it reads them due to the decompression stream)
               (the resulting string is saved into a variable)
             it cleans up, it closes all three streams:
               - the reader
               - the memory
               - and the decompression
             if the resulting string is an xml then it converts it to a de-serialized object
             finally it outputs the results               

.EXAMPLE
    PS C:\>$str = Get-Service | Select -First 1 | ConvertTo-Base64
    PS C:\>$str | ConvertFrom-Base64
#>

[OutputType([String],[Object])]
[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$InputString
)

Write-Verbose "Original/Compressed Size: $('{0:N0}' -f $InputString.Length)"
$data   = [System.Convert]::FromBase64String($InputString)
$ms     = [System.IO.MemoryStream]::new()
$ms.Write($data, 0, $data.Length)
$ms.Seek(0,0) | Out-Null
$mode   = [System.IO.Compression.CompressionMode]::Decompress
$gz     = [System.IO.Compression.GZipStream]::new($ms, $mode)
$sr     = [System.IO.StreamReader]::new($gz)
$OutStr = $sr.ReadToEnd()
$sr.Close()
$ms.Close()
$gz.Close()
Write-Verbose "Uncompressed Size: $('{0:N0}' -f $OutStr.Length)"

if ([bool]($OutStr -as [xml])) {
    $OutObj = [Management.Automation.Psserializer]::Deserialize($OutStr)
    Write-Output $OutObj
}
else {
    Write-Output $OutStr
}

}