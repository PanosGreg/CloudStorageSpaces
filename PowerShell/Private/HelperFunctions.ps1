function Prefix {
<#
.SYNOPSIS
    Outputs a small string with a timestamp that can be used as a prefix in log files
.EXAMPLE
    # in a function, when writing verbose messages, add this prefix
    Write-Verbose "$(Prefix)Script started"  # --> [panos@DESKTOP 12/03/2018 15:31:42]::Script Started
#>
    $CurrentDate = [datetime]::Now.ToString('dd/MM/yy HH:mm:ss')
    $Computer    = [System.Environment]::MachineName
    $CurrentUser = [System.Environment]::UserName
    '[{0}@{1} {2}]::' -f $CurrentUser,$Computer,$CurrentDate
}

function Run-ExternalProcess {
[CmdletBinding()]
param([scriptblock]$Scriptblock,$ArgumentList,[int]$Interval=5)
    $cmd = [System.Management.Automation.PowerShell]::Create()
    [void]$cmd.AddScript($scriptblock)
    if ($PSBoundParameters.ContainsKey('ArgumentList')) {
        $ArgumentList | foreach {[void]$cmd.AddArgument($_)} # <-- variable order matters here
    }
    $async = $cmd.BeginInvoke()
    $Timer = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $async.IsCompleted) {
        [System.Threading.Thread]::Sleep(1000)  # <-- check every 1 second
        $sec = [int]$Timer.Elapsed.TotalSeconds
        if (($sec % $Interval) -eq 0) {  # <-- output "waiting" message every $Interval seconds 
            $msg = 'Waiting for process to complete...'
            if ($sec -le 59) {Write-Verbose "$(Prefix)$msg ($sec sec)"}
            else {$Emin = $Timer.Elapsed.Minutes ; $Esec = $Timer.Elapsed.Seconds
                  Write-Verbose "$(Prefix)$msg ($Emin min $Esec sec)"}
        }
    } #while
    $results = $cmd.EndInvoke($async)  # <-- normal output
    $sec     = [int]$Timer.Elapsed.TotalSeconds
    $Timer.Stop()
    $StdLog = [string]::Join([Environment]::NewLine,$results)
    if ([bool]$cmd.Streams.Error) {
        $ErrLog = $cmd.Streams.Error.Exception.Message -join [System.Environment]::NewLine
        $out    = $StdLog,$ErrLog -join [System.Environment]::NewLine # <-- errors will be shown last
    }
    else {$out = $StdLog}
    Write-Verbose "$(Prefix)Process complete ($sec sec)"
    Write-Output $out  # <-- [string]
    $cmd.Dispose()
}

Function ConvertTo-PrettyCapacity {
<#
.SYNOPSIS
    Convert raw bytes into prettier capacity strings.
.DESCRIPTION
    Takes an integer of bytes, converts to the largest unit (kilo-, mega-, giga-, tera-)
    that will result in at least 1.0, rounds to given precision, and appends standard unit symbol
.PARAMETER Bytes
    The capacity in bytes.
.PARAMETER UseBaseTwo
    Toggle use of binary units and prefixes (mebi, gibi) rather than standard (mega, giga)
.PARAMETER RoundTo
    The number of decimal places for rounding, after conversion
#>

Param (
    [Parameter(Mandatory,ValueFromPipeline = $True)]
    [Int64]$Bytes,

    [Int64]$RoundTo = 0,
    [Switch]$UseBaseTwo # Base-10 by Default
)

If ($Bytes -Gt 0) {
    $BaseTenLabels = ("bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
    $BaseTwoLabels = ("bytes", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB")
    If ($UseBaseTwo) {
        $Base   = 1024
        $Labels = $BaseTwoLabels
    }
    Else {
        $Base   = 1000
        $Labels = $BaseTenLabels
    }
    $Order   = [Math]::Floor( [Math]::Log($Bytes, $Base) )
    $Rounded = [Math]::Round($Bytes/( [Math]::Pow($Base, $Order) ), $RoundTo)
    [String]($Rounded) + $Labels[$Order]
}
Else { 0 }
Return
}

Function ConvertTo-PrettyPercentage {
<#
.SYNOPSIS
    Convert (numerator, denominator) into prettier percentage strings.
.DESCRIPTION
    Takes two integers, divides the former by the latter, multiplies by 100,
    rounds to given precision, and appends "%".
#>

Param (
    [Parameter(Mandatory)]
    [Int64]$Numerator,

    [Parameter(Mandatory)]
    [Int64]$Denominator,

    [Int64]$RoundTo = 1   # <-- number of decimal places for rounding
)

If ($Denominator -Ne 0) { # <-- Cannot Divide by Zero
    $Fraction   = $Numerator / $Denominator
    $Percentage = $Fraction * 100
    $Rounded    = [Math]::Round($Percentage, $RoundTo)
    [String]($Rounded) + "%"
}
Else { 0 }
Return
}
