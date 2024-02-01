#Requires RunAsAdministrator

$WorkingDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

$OutputFileName = "StaleDevices-" + $(Get-Date -Format "MM-dd-yyyy-HHmm") + ".csv"

$OutputFilePath = Join-Path -Path $WorkingDirectory -ChildPath $OutputFileName

$Date = (Get-Date).AddDays(-90)

$RSAT = Get-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"

if ($RSAT.State -eq "NotPresent") {

    Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"

}

# Connect to Microsoft Graph and request the ability to read Audit logs and Users and modify Intune Devices
Connect-MgGraph -Scopes DeviceManagementManagedDevices.Read.All, Device.Read.All -NoWelcome

$StaleDevices = Get-MgDevice -All | Where-Object {$_.ApproximateLastSignInDateTime -ge $Date}

$StaleDevices | `
    Select-Object -Property AccountEnabled, DeviceId, OperatingSystem, OperatingSystemVersion, DisplayName, TrustType, ApproximateLastSignInDateTime | `
        Export-CSV -Path $OutputFilePath -NoTypeInformation