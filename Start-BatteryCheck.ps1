#Requires -Version 5.1

function Get-SleepTime {
    [CmdletBinding()]
    param ()

    function Convert-IdleHexToSeconds {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]
            $PowerOutput
        )
    
        [int] (($PowerOutput -match 'Current DC Power Setting Index:\s') -replace '.*[^0x\d{6}$]') / 60
    }
    
    [string]   $powerCfg = 'powercfg'
    [string[]] $scheme   = @('/Query', 'SCHEME_CURRENT')
    
    [int] $dc_diskIdle  = Convert-IdleHexToSeconds { & $powerCfg $scheme SUB_SLEEP STANDBYIDLE }
    [int] $dc_videoIdle = Convert-IdleHexToSeconds { & $powerCfg $scheme SUB_VIDEO VIDEOIDLE }

    [pscustomobject]@{
        DiskIdleDcSeconds   = $dc_diskIdle
        ScreenIdleDcSeconds = $dc_videoIdle
    }
}



function Start-BatteryCheck {
    <#
    .SYNOPSIS
        Gets running time of a laptop battery.

    .DESCRIPTION
        Start-BatteryCheck writes timestamps to a CSV as long as the laptop is runnning on battery, and should
        run until the system powers off automatically. The first and last timestamps in the CSV can be used in a
        timespan to determine how long the battery was running for.

        This script executes itself when calling it, so there is no need for dot sourcing.
        
        Executing the script with the battery charger connected prompts the message "When ready, disconnect battery
        charger". Immediately after disconnecting the battery charger, the script begins the battery check.

        Executing the script with the battery charger disconnected returns the message "Starting battery check..."

        During the battery check, timestamps are written to a CSV every 1 second, along with the computer name.

        If at any time during the battery check the battery charger is reconnected, the script pauses writing to
        the CSV and prompts the user to disconnect the battery charger to resume.

    .PARAMETER Path
        The path to save the CSV

    .NOTES
        Author: Aaron Hardy

    .INPUTS
        None
    
    .OUTPUTS
        None
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(
            ParameterSetName                = 'Default',
            Position                        = 0,
            ValueFromPipeline               = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( { Test-Path -Path (Split-Path -Path $_ -Parent) } )]
        [System.IO.FileInfo]
        $Path = "$env:USERPROFILE\Desktop\BatteryCheck.csv",

        [Parameter(ParameterSetName = 'ResetIdleSettings')]
        [switch]
        $RestoreIdleSettings
    )

    if ($Null -eq (Get-CimInstance -ClassName Win32_Battery)) {
        Write-Output "Battery not detected"
        break
    }

    [string] $originalIdleSettingsPath = "$env:USERPROFILE\Desktop\original_idle_settings.csv"

    if ($RestoreIdleSettings.IsPresent) {
        $restoreSettings = Import-Csv -Path $originalIdleSettingsPath

        & powercfg setdcvalueindex SCHEME_CURRENT SUB_SLEEP STANDBYIDLE $restoreSettings.DiskIdleDcSeconds
        & powercfg setdcvalueindex SCHEME_CURRENT SUB_VIDEO VIDEOIDLE $restoreSettings.ScreenIdleDcSeconds

        Write-Output "Restored idle settings"
    }

    try {
        [scriptblock] $batteryStatus = { (Get-CimInstance -ClassName Win32_Battery).BatteryStatus }
    } catch {
        Write-Error $_ -ErrorAction Stop
    }

    Get-SleepTime | Export-Csv -Path $originalIdleSettingsPath -NoTypeInformation -Force

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
                    SerialNumber          = (Get-CimInstance -Classname Win32_Bios).SerialNumber
                    ComputerName          = $env:COMPUTERNAME
                    BatteryCheckTimeStamp = Get-Date
                }

                $entry | Export-Csv -Path $Path -Append -NoTypeInformation

                Start-Sleep -Seconds 1
            }
        } until (0 -gt 1)
    } else {
        Start-BatteryCheck
    }
}

Start-BatteryCheck
