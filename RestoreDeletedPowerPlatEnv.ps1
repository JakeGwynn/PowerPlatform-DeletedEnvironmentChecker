param (
    [Parameter (Mandatory = $true)]
    [int] $ListItemID,
	[Parameter (Mandatory = $true)]
    [string] $EnvironmentName
)
$TenantId = Get-AutomationVariable -Name TenantId
$SiteUrl = Get-AutomationVariable -Name SiteUrl
$ListName = Get-AutomationVariable -Name ListName


$SpoCred = Get-AutomationPSCredential -Name "SpoAppRegistration"
$PpCred = Get-AutomationPSCredential -Name "PpAppRegistration"

Connect-PnPOnline -Url $SiteUrl -ClientId $SpoCred.UserName -ClientSecret $SpoCred.GetNetworkCredential().Password
Add-PowerAppsAccount -TenantID $TenantId -ApplicationId $PpCred.UserName -ClientSecret $PpCred.GetNetworkCredential().Password

$SpoValues = @{
	"EnvRestored" = $true
}

try {
	Write-Output "Attemping environment recovery: $EnvironmentName"
	Write-Output "<br>"
	Write-Output "<br>"
	Recover-AdminPowerAppEnvironment -EnvironmentName $EnvironmentName -WaitUntilFinished $true
	Set-PnPListItem -List "SoftDeletedEnvironments" -Identity $ListItemID -Values $SpoValues
	Write-Output "Environment recovery successful"
}
catch {
	Write-Output "Failed to recover environment $EnvironmentName"
	Write-Output "<br>"
	Write-Output "<br>"
	Write-Output "PowerShell Error Details: "
	Write-Output "<br>"
	Write-Output "<br>"
    $Err = $_
	$_ | get-member | foreach-object {
		if ($_.MemberType -in @("Property", "ScriptProperty")) {
			$ErrorPropName = $_.Name
			Write-Output "Error Property: $ErrorPropName"
			Write-Output "<br>"
            $ErrorProp = $Err.$ErrorPropName
			Write-Output $ErrorProp
			Write-Output "<br>"
            Write-Output "<br>"
		}
	}
}

Disconnect-PnPOnline
Remove-PowerAppsAccount