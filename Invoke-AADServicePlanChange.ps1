#Requires -PSEdition 'Desktop'
#Requires -Version 5.1
#Requires -Modules AzureAD

function Invoke-AADServicePlanChange {
    <#
    .SYNOPSIS
        Assigns AzureAD licensing with custom service plans.
    .DESCRIPTION
        Invoke-AADServicePlanChange ensures a user's assigned license is provisioned with specific service plans
        enabled and disabled.

        The assigned license's SkuId is required and each service plan's ServicePlanId is required.

    .EXAMPLE
        PS C:\Scripts> 'user@school.edu' | Invoke-AADServicePlanChange `
        >> -AzureADSubscribedSkuId 18250162-5d87-4436-a834-d795c15c80f3 `
        >> -EnableServicePlanId 57ff2da0-773e-42df-b2af-ffb7a2317929, a23b959c-7ce8-4e57-9140-b90eb88a9e97 `
        >> -DisableServicePlanId efb87545-963c-4e0d-99df-69c6916d9eb0, 9e700747-8b1d-45e5-ab8d-ef187ceec156,
        >> 2078e8df-cff6-4290-98cb-5408261a760a

        This example targets the M365EDU_A3_STUUSEBNFT SKU (SkuId 18250162-5d87-4436-a834-d795c15c80f3) on the user
        account. If the SKU is not assigned to the account, the script will attempt to do so.
        
        Once assigned, the script will ensure specified service plans are enabled or disabled.

        Enabled:
            57ff2da0-773e-42df-b2af-ffb7a2317929    TEAMS1
            a23b959c-7ce8-4e57-9140-b90eb88a9e97    SWAY

        Disabled:
            efb87545-963c-4e0d-99df-69c6916d9eb0    EXCHANGE_S_ENTERPRISE
            9e700747-8b1d-45e5-ab8d-ef187ceec156    STREAM
            2078e8df-cff6-4290-98cb-5408261a760a    YAMMER
    
    .NOTES
        Author: Aaron Hardy
        Version: 1.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory                       = $true,
            Position                        = 0,
            ValueFromPipeline               = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $UserPrincipalName,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AzureADSubscribedSkuId,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $EnableServicePlanId,

        [Parameter(Mandatory = $true, Position = 3)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $DisableServicePlanId
    )

    begin {
        [System.Array]   $tenantSku             = Get-AzureADSubscribedSku -ErrorAction Stop
        [pscustomobject] $requiredSku           = ($tenantSku |
            Where-Object -FilterScript { $_.SkuId -eq $AzureADSubscribedSkuId })

        [string] $requiredSkuId         = $requiredSku.SkuId
        [string] $requiredSkuPartNumber = $requiredSku.SkuPartNumber

        if (-not ($requiredSkuId)) {
            Write-Output "SKU $requiredSkuId could not be found in your tenant."
            break
        }
    }#begin

    process {
        $UserPrincipalName | ForEach-Object -Process {
            $upn              = $_
            $aadUser          = Get-AzureADUser -SearchString $upn
            $assignedLicenses = $aadUser | Select-Object -ExpandProperty AssignedLicenses

            if ($assignedLicenses.SkuId -contains $requiredSkuId) {
                "SKU $requiredSkuPartNumber ($requiredSkuId) assigned to $upn"
            } else {
                # user doesn't have required license, enable it
                try {
                    $license                      = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
                    $license.SkuId                = $AzureADSubscribedSkuId
                    $licensesToAssign             = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
                    $licensesToAssign.AddLicenses = $License

                    $splat = @{
                        ObjectId = $aadUser.ObjectId
                        AssignedLicenses = $licensesToAssign
                        ErrorAction = 'Stop'
                    }
                    Set-AzureADUserLicense @splat
                    Write-Output "Assigned license to user: $requiredSkuPartNumber (SkuId: $requiredSkuId)"
                } catch {
                    continue
                    # failed to enable license, go to next account
                }
            }

            [string[]] $disabledPlans = $assignedLicenses | Select-Object -ExpandProperty DisabledPlans |
                Where-Object { $_ -notin $EnableServicePlanId }

            $disabledPlans += ($DisableServicePlanId | Where-Object { $_ -notin $disabledPlans })

            $license               = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
            $license.SkuId         = $AzureADSubscribedSkuId
            $license.DisabledPlans = $disabledPlans

            $licensesToAssign             = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
            $licensesToAssign.AddLicenses = $license

            [string] $userIdentity = "{0}" -f $aadUser.UserPrincipalName, $aadUser.ObjectId

            try {
                Set-AzureADUserLicense -ObjectId $aadUser.ObjectId -AssignedLicenses $licensesToAssign
                Write-Output "Completed service plan change for $userIdentity"
            } catch {
                Write-Error "Failed to process $userIdentity"
            }
        }#ForEach
    }#process
}#function