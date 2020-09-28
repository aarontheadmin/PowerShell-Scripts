function Disable-ServicePlan {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory                       = $true,
            ValueFromPipeline               = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $UserPrincipalName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AccountSkuId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name
    )

    process {
        foreach ($userPN in $UserPrincipalName) {
            try {
                $licenses = (Get-MsolUser -UserPrincipalName $userPN).Licenses |
                    Where-Object -FilterScript { $_.AccountSKUId -eq $AccountSkuId }

                $disabledServices = ($licenses.ServiceStatus |
                        Where-Object -FilterScript {
                            $_.ProvisioningStatus -eq 'Disabled' }).ServicePlan.ServiceName

                # Remove Teams, since we do not want that to be disabled
                $disabledServices = @($disabledServices, @($Name))
                $licenseOptions = New-MsolLicenseOptions -AccountSkuId $AccountSkuId -DisabledPlans $disabledServices

                Set-MsolUserLicense -UserPrincipalName $userPN -LicenseOptions $licenseOptions -ErrorAction Stop
                Write-Output "Disabled service plan(s) for $userPN"
            } catch {
                Write-Error $_
            }
        }
    }
}

function Enable-ServicePlan {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory                       = $true,
            ValueFromPipeline               = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $UserPrincipalName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AccountSkuId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name
    )

    foreach ($userPN in $UserPrincipalName) {
        # Get the licenses for the user, extract services which are disabled
        $licenses = (Get-MsolUser -UserPrincipalName $userPN).Licenses |
            Where-Object -FilterScript { $_.AccountSKUId -eq $AccountSkuId }

        $disabledServices = ($licenses.ServiceStatus |
                Where-Object -FilterScript {
                    $_.ProvisioningStatus -eq 'Disabled' }).ServicePlan.ServiceName

        # Remove Teams, since we do not want that to be disabled
        $disabledServices = $disabledServices | Where-Object -FilterScript { $_ -notin $Name }

        # Create a new licensing option for this SKU
        $NewOptions = New-MsolLicenseOptions -AccountSkuId $AccountSkuId -DisabledPlans $disabledServices

        # Apply the options to the user
        Set-MsolUserLicense -UserPrincipalName $userPN -LicenseOptions $NewOptions

        Write-Output "Enabled services for $userPN"
    }
}

[string[]] $users        = 'user@site.edu'
[string[]] $serviceNames = 'TEAMS1'

# first enable Teams
foreach ($user in $users) {
    $splat = @{
        UserPrincipalName = $user
        AccountSkuId      = 'biblewayacademy:M365EDU_A3_STUUSEBNFT'
        Name              = $serviceNames
    }
    Enable-ServicePlan @splat
}

# wait for previous licensing changes to propagate
Start-Sleep -Seconds 30

# Disable
foreach ($user in $users) {
    $splat = @{
        UserPrincipalName = $user
        AccountSkuId      = 'biblewayacademy:M365EDU_A3_STUUSEBNFT'
        Name              = $serviceNames
    }
    Disable-ServicePlan @splat
}