#Requires -runasadministrator
#Requires -modules "Microsoft.Graph.Authentication", "Microsoft.Graph.Identity.DirectoryManagement", "Microsoft.Graph.DeviceManagement"


$WorkingDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

$OutputFileName = "StaleDevices-" + $(Get-Date -Format "MM-dd-yyyy-HHmm") + ".csv"

$OutputFilePath = Join-Path -Path $WorkingDirectory -ChildPath $OutputFileName

$Date = (Get-Date).AddDays(-90)

$RSAT = Get-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"

if ($RSAT.State -eq "NotPresent") {

    Write-Host "Installing the RSAT Active Directory Tools ..."

    Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"

}

# Connect to Microsoft Graph and request the ability to read Audit logs and Users and modify Intune Devices
Connect-MgGraph -Scopes DeviceManagementManagedDevices.Read.All, Device.Read.All -NoWelcome

$StaleDevices = Get-MgDevice -All | Where-Object {$_.ApproximateLastSignInDateTime -ge $Date}

foreach ($StaleDevice in $StaleDevices) {

    if ($StaleDevice.TrustType -eq "ServerAD") {

        $ADComputer = Get-ADComputer -Identity $StaleDevice.DisplayName

        if ($ADComputer.ObjectGUID -eq $StaleDevice.DeviceId) {

            $ADComputerName = $ADComputer.Name

            $ADComputerLastLogonDate = $ADComputer.LastLogonDate

            $StaleDevice.AccountEnabled, $StaleDevice.DeviceId, $StaleDevice.OperatingSystemVersion, $StaleDevice.DisplayName, $StaleDevice.TrustType, $StaleDevice.ApproximateLastSignInDateTime, $ADComputerName, $ADComputerLastLogonDate | Export-CSV -Path $OutputFilePath -NoTypeInformation
        }

    }
}