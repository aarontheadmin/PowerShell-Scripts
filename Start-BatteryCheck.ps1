function Start-BatteryCheck {
    <#
    .SYNOPSIS
        Gets running time of a laptop battery.

    .DESCRIPTION
        Start-BatteryCheck writes timestamps to a CSV as long as the laptop is runnning on battery, and should
        run until the system powers off automatically. The first and last timestamps in the CSV can be used in a
        timespan to determine how long the battery was running for.
        
        Executing the script with the battery charger connected prompts the message "When ready, disconnect battery
        charger". Immediately after disconnecting the battery charger, the script begins the battery check.

        Executing the script with the battery charger disconnected returns the message "Starting battery check..."

        During the battery check, timestamps are written to a CSV every 1 second, along with the computer name.

        If at any time during the battery check the battery charger is reconnected, the script pauses writing to
        the CSV and prompts the user to disconnect the battery charger to resume.

    .PARAMETER LogPath
        The path to save the CSV

    .NOTES
        Author: AccurIT Technology Solutions

    .INPUTS
        None
    
    .OUTPUTS
        None
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( { Test-Path -Path (Split-Path -Path $_ -Parent) } )]
        [System.IO.FileInfo]
        $LogPath = "$env:USERPROFILE\Desktop\BatteryCheck.csv"
    )

    $batteryStatus = { (Get-CimInstance -ClassName Win32_Battery).BatteryStatus }

    if ((& $batteryStatus) -eq 2) {
        Write-Output "When ready, unplug battery charger"

        do {
            # wait until charger removed

        } until ((& $batteryStatus) -eq 1)
    }

    if ((& $batteryStatus) -eq 1) {
        Write-Output "Starting battery check..."

        do {
            if ((& $batteryStatus) -ne 1) {
                Start-BatteryCheck
            } else {
                $entry = [pscustomobject]@{
                    ComputerName          = $env:COMPUTERNAME
                    BatteryCheckTimeStamp = Get-Date
                }

                $entry | Export-Csv -Path $LogPath -Append -NoTypeInformation

                Start-Sleep -Milliseconds 500
            }
        } until (0 -gt 1)
    } else {
        Start-BatteryCheck
    }
}

Start-BatteryCheck