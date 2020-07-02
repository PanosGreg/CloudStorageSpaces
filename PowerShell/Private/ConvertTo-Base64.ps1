Function ConvertTo-Base64 {

<#
.SYNOPSIS
    It transforms a PS object or a String into a Base64 encoded string

.DESCRIPTION
    This function takes either a string or a ps object and it compresses and then 
    encodes it with Base64 encoding.

    Input:  PS Object OR String
    Output: Base64 string, which is essentially an array of bytes

    Process: it takes a string or if it's a PS object it converts it to a string
               (the conversion means it serializes the PS Object into XML)
             then it creates a memory stream
             then it wraps the memory stream on a compression stream
             then it wraps the compression stream on a writer stream
             then is writes the string in the streamwriter
               (which gets compressed due to the compression stream)
               (which then gets written into memory due to the memory stream)
             then it closes the writer stream (this needs to be done now, not at the end)
               (so now the memory stream is filled up)
             it converts the memory stream into an array of bytes
             then it encodes the bytes with Base64 encoding
               (the resulting string is saved into a variable)
             it cleans up, it closes the two remaining streams:
               - the memory
               - and the compression
             finally it outputs the results

.EXAMPLE
    PS C:\>Get-Service | Select -First 1 | ConvertTo-Base64

.EXAMPLE
    PS C:\>$scriptblock = {
        Get-Service
        Get-Process
    }
    ConvertTo-Base64 [string]$scriptblock
#>

    [OutputType([String])]
    [CmdletBinding(DefaultParameterSetName='PSObject')]
    param (
        [Parameter(ParameterSetName='PSObject',
                   Position = 0,
                   Mandatory,
                   ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [object]$InputObject,

        [Parameter(ParameterSetName='String',
                   Position = 0,
                   Mandatory,
                   ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$InputString
    )

# Check if input is a PSObject then
# Convert object to a string (which is XML-based serialization)
if ($psCmdlet.ParameterSetName -eq 'PSObject') {
    $InputString = [management.automation.psserializer]::Serialize($InputObject)
}

Write-Verbose "Original/Uncompressed Size: $('{0:N0}' -f $InputString.Length)"
$ms     = New-Object System.IO.MemoryStream
$mode   = [System.IO.Compression.CompressionMode]::Compress
$gz     = New-Object System.IO.Compression.GZipStream($ms, $mode)
$sw     = New-Object System.IO.StreamWriter($gz)
$sw.Write($InputString)
$sw.Close()
$bytes  = $ms.ToArray()
$OutStr = [System.Convert]::ToBase64String($bytes)
$ms.Close()
$gz.Close()
Write-Verbose "Compressed Size: $('{0:N0}' -f $OutStr.Length)"
Write-Output $OutStr

}