function Invoke-AADLicenseChange {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $UserPrincipalName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $SkuPartNumber,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $NewSkuPartNumber
    )

    $UserPrincipalName | ForEach-Object -Process {
        [string] $userUPN = $_
      
        # Unassign licenses
        $oldLicenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses

        $oldLicenses.RemoveLicenses = foreach ($sku In $SkuPartNumber) {
            Get-AzureADSubscribedSku |
                Where-Object -Property SkuPartNumber $sku -EQ |
                Select-Object -ExpandProperty SkuID
        }

        Set-AzureADUserLicense -ObjectId $userUPN -AssignedLicenses $oldLicenses -ErrorAction Stop

        # Assign licenses
        $allNewLicenses = foreach ($newSku in $NewSkuPartNumber) {
            $newLicense = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense

            $newLicense.SkuId = Get-AzureADSubscribedSku |
                Where-Object -Property SkuPartNumber -Value $newSku -EQ |
                Select-Object -ExpandProperty SkuID

            $newLicense
        }

        $newLicenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
        $newLicenses.AddLicenses = $allNewLicenses

        Set-AzureADUserLicense -ObjectId $userUPN -AssignedLicenses $newLicenses -ErrorAction Stop

        Write-Output "Processed $userUPN"
    }
}