#Requires -Version 5.1
#Requires -PSEdition Desktop

function Invoke-AADLicenseChange {
    <#
    .SYNOPSIS
        Removes old licenses and adds new licenses in AAD.

    .DESCRIPTION
        Invoke-AADLicenseChange can be used to remove specific licenses before assigning new licenses to one or
        more users in Azure AD. This ensures conflicting licenses are removed before a higher license is assigned.

        For example, "Office 365 A1 Plus for students" must be removed before assigning/upgrading to a 
        "Microsoft 365 A3 for students use benefit" license.

        Multiple licenses can be added without specifying any to remove, vice versa.

    .PARAMETER UserPrincipalName
        The user principal name (email address)

    .PARAMETER SkuPartNumber
        The SKU part number of the license to be removed from the account.

    .PARAMETER NewSkuPartNumber
        The SKU part number of the license to be added to the account.

    .EXAMPLE
        PS C:\Scripts\> Invoke-AADLicenseChange -UserPrincipalName student@domain.edu `
        >> -SkuPartNumber STANDARDWOFFPACK_IW_STUDENT -NewSkuPartNumber M365EDU_A3_STUUSEBNFT
        Processed student@domain.edu

        The example above removes "Office 365 A1 Plus for students" license and assigns a "Microsoft 365 A3 for
        students use benefit" license.

    .EXAMPLE
        PS C: \Scripts\> $array = 'student.1@domain.edu', 'student.2@domain.edu', 'student.3@domain.edu'
        PS C: \Scripts\> $array | Invoke-AADLicenseChange -SkuPartNumber STANDARDWOFFPACK_IW_STUDENT `
        >> -NewSkuPartNumber M365EDU_A3_STUUSEBNFT
        Processed student.1@domain.edu
        Processed student.2@domain.edu
        Processed student.3@domain.edu

        The example above shows an array of student accounts piped to Invoke-AADLicenseChange. The result for each
        account is the "Office 365 A1 Plus for students" license is removed and then the "Microsoft 365 A3 for
        students use benefit" license is assigned.

    .NOTES
        Authored by Aaron Hardy 2020
        Version 1.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory                       = $true,
            ValueFromPipeline               = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $UserPrincipalName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $SkuPartNumber,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $NewSkuPartNumber
    )

    process {
        $UserPrincipalName | ForEach-Object -Process {
            [string] $userUPN = $_
        
            # Unassign licenses
            if ($SkuPartNumber.Count -gt 0) {
                $oldLicenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses

                $oldLicenses.RemoveLicenses = foreach ($sku In $SkuPartNumber) {
                    Get-AzureADSubscribedSku |
                        Where-Object -Property SkuPartNumber $sku -EQ |
                        Select-Object -ExpandProperty SkuID
                }

                Set-AzureADUserLicense -ObjectId $userUPN -AssignedLicenses $oldLicenses -ErrorAction Stop
            }

            # Assign licenses
            if ($NewSkuPartNumber.Count -gt 0) {
                $allNewLicenses = foreach ($newSku in $NewSkuPartNumber) {
                    $newLicense = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense

                    $newLicense.SkuId = Get-AzureADSubscribedSku |
                        Where-Object -Property SkuPartNumber -Value $newSku -EQ |
                        Select-Object -ExpandProperty SkuID

                    $newLicense
                }

                $newLicenses             = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
                $newLicenses.AddLicenses = $allNewLicenses

                Set-AzureADUserLicense -ObjectId $userUPN -AssignedLicenses $newLicenses -ErrorAction Stop
            }

            Write-Output "Processed $userUPN"
        }#foreach
    }#process
}#function