Function Convert-Temperature {
    <#
    .SYNOPSIS
    Converts between Celsius and Fahrenheit.
    
    .DESCRIPTION
    Converts temperatures between Celsius and Fahrenhiet, vice-versa.
    
    .PARAMETER Celsius
    Converts the Value to Celsius.
    
    .PARAMETER Fahrenheit
    Coverts the Value to Fahrenheit.
    
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory,
            Position          = 0,
            ValueFromPipeline = $true)]
        [double[]]
        $Value,

        [Parameter(ParameterSetName = 'Celsius')]
        [switch]
        $Celsius,

        [Parameter(ParameterSetName = 'Fahrenheit')]
        [switch]
        $Fahrenheit
    )

    BEGIN {
        if ($Fahrenheit.IsPresent) {
            [string]$formula = "(( 9 * tempValue) / 5) + 32"
        }
        else {
            [string]$formula = "(5 * (tempValue - 32)) / 9"
        }
    }

    PROCESS {

        foreach ($temperature in $Value) {

            [double]$result        = Invoke-Expression (($formula).Replace('tempValue', $temperature))
            [double]$roundedResult = [System.Math]::Round($result, 2)

            Write-Output $roundedResult
        }
    }
}