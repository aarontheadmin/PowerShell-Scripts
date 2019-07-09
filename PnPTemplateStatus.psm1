function Get-PnPTemplateStatus {
    <#
    .SYNOPSIS
        Gets the template status of a PnP list item.

    .DESCRIPTION
        Gets the template status of a PnP list item(s) based on the list name
        specified. More than one list item can be checked by specifying the
        Range Start Id and the Range End Id (must be equal to or larger than
        the Start Range Id).

        Note: An established connection to SharePoint site is required.
    
    .PARAMETER List
        The name of the PnP list.
    
    .PARAMETER RangeStartId
        The site index number to start the range.
    
    .PARAMETER RangeEndId
        The site index number to end the range with. This number must be equal
        to or great than the number specified as the RangeStartId.
    
    .EXAMPLE
        PS >Get-PnPTemplateStatus -List 'MigrationLog' -RangeStartId 400 -RangeEndId 450

    .INPUTS
        None

    .OUTPUTS
        TBD

    .NOTES
        Created by Gilbert Okello and Aaron Hardy
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $List,

        [Parameter(ValueFromPipeline, HelpMessage = 'The ID to start the range with')]
        [uint64] $RangeStartId = 1,

        [Parameter(ValueFromPipeline, HelpMessage = 'The ID to end the range with')]
        [ValidateScript( { $_ -ge $PSBoundParameters['RangeStartId'] })]
        [uint64] $RangeEndId = 1
    )
    
    [pscustomobject]$pnpListItemParams = @{
        List  = $List
        Query = '<View>' +
        '<Query><Where>' +
        '<And>' +
        "<Eq><FieldRef Name='TemplateApplied'/><Value Type='Boolean'>1</Value></Eq>" +
        '<And>' +
        "<Geq><FieldRef Name='ID'/><Value Type='Integer'>$RangeStartId</Value></Geq>" +
        "<Lt><FieldRef Name='ID'/><Value Type='Integer'>$RangeEndId</Value></Lt>" +
        '</And>' +
        '</And></Where></Query></View>'
        ErrorAction = 'Stop'
    }

    try {
        Get-PnPListItem @pnpListItemParams
    }
    catch {
        Write-Error $_ -ErrorAction Stop
    }
    
}#Get-PnPTemplateStatus


function Invoke-PnPTemplateCheck {
    <#
    .SYNOPSIS
        Reports if a feature and/or template have been applied to a SharePoint list.

    .DESCRIPTION
        Reports if a feature and/or template have been applied to a SharePoint list. Results can be
        exported to a CsvPath.

    .PARAMETER Url
        The SharePoint site URL.

    .PARAMETER PnPList
        The name of the list to query.

    .PARAMETER PnPFieldListName
        The list name of the PnPField.

    .PARAMETER PnPFieldIdentity
        The identity of the PnPField.

    .PARAMETER RangeStartId
        The site index number to start the range.
    
    .PARAMETER RangeEndId
        The site index number to end the range with. This number must be equal
        to or great than the number specified as the RangeStartId.

    .PARAMETER CsvPath
        The file path to save the CSV file.

    .EXAMPLE
        PS >$csvPath = 'C:\Users\me\OneDrive\Work\that other company\Scripts\TemplateApplied-40.Csv'
        PS >Invoke-PnPTemplateCheck -Url https://abc.sharepoint.com -PnPList MigrationLog -PnPFieldListName Documents -PnPFieldIdentity DocumentType -RangeStartId 10 -RangeEndId 40 -CsvPath $csvPath

    .INPUTS
        None

    .OUTPUTS
        TBD

    .NOTES
        Created by Gilbert Okello and Aaron Hardy
    #>
    [CmdletBinding()]
    param (
        [Alias('Uri')]
        [Parameter(Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = 'The site URI')]
        [uri] $Url,

        [Parameter(Mandatory)]
        [string] $PnPList,

        [Parameter(Mandatory)]
        [string] $PnPFieldListName,

        [Parameter(Mandatory)]
        [string] $PnPFieldIdentity,

        [Parameter(Mandatory)]
        [uint64] $RangeStartId,

        [Parameter(Mandatory)]
        [ValidateScript( { $_ -ge $PSBoundParameters['RangeStartId'] })]
        [uint64] $RangeEndId,

        [Parameter()]
        [ValidateScript( {
                (Test-Path -Path (Split-Path -Path $_ -Parent)) -and
                $_.Extension -eq '.csv'
            })]
        [System.IO.FileInfo] $CsvPath
    )


    # try connecting online using the Site URL
    try {
        Connect-PnPOnline -Url $Url -UseWebLogin -ErrorAction Stop
    }#try
    catch {
        Write-Error $_ -ErrorAction Stop
    }#catch


    # No connection error, create initial object properties
    try {
        $listItems = Get-PnPTemplateStatus -List $PnPList -RangeStartId $RangeStartId -RangeEndId $RangeEndId -ErrorAction Stop
    }
    catch {
        Write-Error $_ -ErrorAction Stop
    }
    
    # Output lists within range with the "HasFeature" and "HasTemplate" results.
    $listItems | & {
        process {
            $siteURL  = $_["SiteURL"]
            $siteName = $_["SiteName"]
            $siteID   = $_["SiteID"]
            $ID       = $_["ID"]

            [pscustomobject]$siteMetadata = @{
                SiteID   = $siteID
                SiteName = $siteName
                SiteURL  = $siteURL
                ID       = $ID
            }


            # try if the feature exists in the site
            try {
                $null = Get-PnPField -List $PnPFieldListName -Identity $PnPFieldIdentity -ErrorAction Stop

                # Feature exists, add properties to object with "YES" values
                $siteMetadata['HasFeature']  = $true
                $siteMetadata['HasTemplate'] = $true # A separate function should check if the template is applied rather than assuming here
            }#try
            catch {
                # Feature does not exist (nor will template be applied);
                # add properties to object with "NO" values
                $siteMetadata['HasFeature']  = 'NO'
                $siteMetadata['HasTemplate'] = 'NO'
            }#catch
            
            Write-Output $siteMetadata
        
        }#process
    } |
    Tee-Object -Variable pnpTemplateResult # foreach, Tee-Object

    # CsvPath specified and more than 0 objects returned, export results to csv file
    if (($PSBoundParameters['CsvPath']) -and ($pnpTemplateResult.Count -gt 0)) {
        $pnpTemplateResult | Export-Csv $CsvPath -Force -NoTypeInformation
    }#if
}#Invoke-PnPTemplateCheck