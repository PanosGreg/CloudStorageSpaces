function Remove-Comments {
<#
.SYNOPSIS
    Removes all single line comments, in-line comments, as well as multi line comments
    from a scriptblock.
    It also removes any whitespaces as well as empty newlines
.EXAMPLE
    $block = {
       # this is a line comment, followed by an empty newline

       $env:COMPUTERNAME  # <-- and this is an in-line comment
    }
    Remove-Comments -Scriptblock $block
#>
[OutputType([String])]
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [Scriptblock]$Scriptblock
)
$ScriptBlockString = $ScriptBlock.ToString()
$Parser        = [Management.Automation.PSParser]::Tokenize($ScriptBlock,[Ref]$Null)
$Tokens        = $Parser.Where({$_.Type -ne 'Comment'})
$StringBuilder = [Text.StringBuilder]::new()
$CurrentColumn = 1
$NewlineCount  = 0
foreach($CurrentToken in $Tokens) {
    # Now output the token
    if(($CurrentToken.Type -eq 'NewLine') -or ($CurrentToken.Type -eq 'LineContinuation')) {
        $CurrentColumn = 1
        # Only insert a single newline. Sequential newlines are ignored in order to save space.
        if ($NewlineCount -eq 0) {
            $StringBuilder.AppendLine() | Out-Null
        }
        $NewlineCount++
    }
    else {
        $NewlineCount = 0
        # Do any indenting
        if($CurrentColumn -lt $CurrentToken.StartColumn) {
            # Insert a single space in between tokens on the same line. Extraneous whiltespace is ignored.
            if ($CurrentColumn -ne 1) {
                $StringBuilder.Append(' ') | Out-Null
            }
        }
        # See where the token ends
        $CurrentTokenEnd = $CurrentToken.Start + $CurrentToken.Length - 1
        # Handle the line numbering for multi-line strings
        if(($CurrentToken.Type -eq 'String') -and ($CurrentToken.EndLine -gt $CurrentToken.StartLine)) {
            $LineCounter = $CurrentToken.StartLine
            $StringLines = $(-join $ScriptBlockString[$CurrentToken.Start..$CurrentTokenEnd] -split '`r`n')
            foreach($StringLine in $StringLines) {
                $StringBuilder.Append($StringLine) | Out-Null
                $LineCounter++
            }
        }
        # Write out a regular token
        else {
            $StringBuilder.Append((-join $ScriptBlockString[$CurrentToken.Start..$CurrentTokenEnd])) | Out-Null
        }
        # Update our position in the column
        $CurrentColumn = $CurrentToken.EndColumn
    }
}
Write-Output $StringBuilder.ToString()
}