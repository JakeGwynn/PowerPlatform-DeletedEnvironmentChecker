param (
    [Parameter (Mandatory = $true)]
    [int] $ListItemID,
	[Parameter (Mandatory = $true)]
    [string] $EnvironmentName,
	[Parameter (Mandatory = $false)]
    [string] $EnvironmentRestoredBy
)
$TenantId = Get-AutomationVariable -Name TenantId
$SiteUrl = Get-AutomationVariable -Name SiteUrl
$ListName = Get-AutomationVariable -Name ListName

$Cred = Get-AutomationPSCredential -Name "AppRegistration"

Connect-PnPOnline -Url $SiteUrl -ClientId $Cred.UserName -ClientSecret $Cred.GetNetworkCredential().Password
Add-PowerAppsAccount -TenantID $TenantId -ApplicationId $Cred.UserName -ClientSecret $Cred.GetNetworkCredential().Password

try {
	Write-Output "Attemping environment recovery: $EnvironmentName"
	Write-Output "<br>"
	Write-Output "<br>"
	Recover-AdminPowerAppEnvironment -EnvironmentName "$EnvironmentName" -WaitUntilFinished $true
	Write-Output "<br>"
	Write-Output "<br>"
	$SpoValues = @{
		"EnvRestored" = $true
		"EnvRestoreDate" = (Get-Date).ToUniversalTime()
		"RestoredBy" = $EnvironmentRestoredBy
	}
	Write-Output "<strong>Environment recovery successful </strong>"
	$EnvironmentRecoverySuccessful = $true
}
catch {
	$Err = $_
	Write-Output '<span style="color: rgb(255,0,0)">Failed to recover environment: ' $EnvironmentName '</span>'
	Write-Output "<br><br>"
	Write-Output "Error Details: "
	Write-Output "<br><br>"
    Write-Output "<strong>Command: </strong>" $Err.InvocationInfo.MyCommand.Name
    Write-Output "<br>"
    Write-Output "<strong>Line: </strong>" $Err.InvocationInfo.ScriptLineNumber "<strong>Character: </strong>" $Err.InvocationInfo.OffsetInLine
    Write-Output "<br><br>"
    Write-Output "<strong>Exception:</strong>"
    Write-Output "<br>"
    Write-Output $Err.Exception
    Write-Output "<br><br>"
    Write-Output "<strong>ErrorDetails:</strong>"
    Write-Output "<br>"
    Write-Output $Err.ErrorDetails.Message 
    Write-Output "<br><br>"
}

if ($EnvironmentRecoverySuccessful) {
	Set-PnPListItem -List "SoftDeletedEnvironments" -Identity $ListItemID -Values $SpoValues
}

Disconnect-PnPOnline
Remove-PowerAppsAccount