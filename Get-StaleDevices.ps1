#Requires -runasadministrator
#Requires -modules "Microsoft.Graph.Authentication", "Microsoft.Graph.Identity.DirectoryManagement", "Microsoft.Graph.DeviceManagement"

<#
.NOTES
This sample script is not supported under any Microsoft standard support program or service. The sample script is provided AS IS without warranty of any kind. Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample script remains with you. 
In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the script be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample script, even if Microsoft has been advised of the possibility of such damages.

.SYNOPSIS

.DESCRIPTION

.PARAMETER StaleDeviceAge
The number of days since the device's last sign-in date

.EXAMPLE
.\Get-StaleDevices.ps1 

.EXAMPLE
.\Get-StaleDevices.ps1 -StaleDeviceAge 120
#>


param (
  [Int]
  $StaleDeviceAge = 90
)

#
# Install the Active Directory Remote Server Administration Tools (RSAT)
#

$RSAT = Get-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"

if ($RSAT.State -eq "NotPresent") {

    Write-Host "Installing the the Active Directory Remote Server Administration Tools (RSAT) ..."

    Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"

}

#
# Install the Microsoft Graph Directory Management and Microsoft Graph Device Management Modules
#

if (-not (Get-Module -ListAvailable -Name "Microsoft.Graph.Identity.DirectoryManagement"))
{
    Install-Module -Name "Microsoft.Graph.Identity.DirectoryManagement" -Repository PSGallery -AllowClobber -Force -AcceptLicense -Confirm:$false
}

if (-not (Get-Module -ListAvailable -Name "Microsoft.Graph.DeviceManagement"))
{
    Install-Module -Name "Microsoft.Graph.DeviceManagement" -Repository PSGallery -AllowClobber -Force -AcceptLicense -Confirm:$false
}

# Connect to Microsoft Graph and request the ability to read all Azure AD Devices and all Intune Managed Devices
Connect-MgGraph -Scopes Device.Read.All, DeviceManagementManagedDevices.Read.All -NoWelcome

#
# Retrieve and filter all Azure AD devices
#

$Date = (Get-Date).AddDays(-$StaleDeviceAge)

# The operator for the date comparison must be -le (less than or equal to)
$StaleAzureADDevices = Get-MgDevice -All | Where-Object {$_.ApproximateLastSignInDateTime -ge $Date}

# Initialize an empty array
$DeviceRecords = @()

# Iterate through each Azure AD device object
foreach ($AzureADDevice in $StaleAzureADDevices) {

    # For Azure AD Hybrid Joined devices, retrieve the corresponding Active Directory Computer objects
    if ($AzureADDevice.TrustType -eq "ServerAD") {

        # Use the Azure AD Device Display Name to find the corresponding AD Computer object
        $ADComputer = Get-ADComputer -Identity $AzureADDevice.DisplayName -ErrorAction SilentlyContinue
        
        # Use the Azure AD Device Id to find the corresponding AD Computer object
        # $ADComputer = Get-ADComputer -Identity $AzureADDevice.DeviceId -ErrorAction SilentlyContinue

    }
    
    # Use the Azure AD Device Display Name to find the corresponding Intune device
    $IntuneDevice = Get-MgDeviceManagementManagedDevice -Filter "DeviceName eq '$($AzureADDevice.DisplayName)'" -ErrorAction SilentlyContinue
    
    # Use the Azure AD Device Id to find the corresponding Intune device
    # $IntuneDevice = Get-MgDeviceManagementManagedDevice -Filter "AzureADDeviceId eq '$($AzureADDevice.DeviceId)'" -ErrorAction SilentlyContinue

    $DeviceRecord = @{

        AzureADDeviceEnabled = $AzureADDevice.AccountEnabled
        AzureADDeviceID = $AzureADDevice.DeviceId
        AzureADDeviceOSVersion = $AzureADDevice.OperatingSystemVersion
        AzureADDeviceDisplayName = $AzureADDevice.DisplayName
        AzureADDeviceTrustType = $AzureADDevice.TrustType
        AzureADDeviceLastSignInDate = $AzureADDevice.ApproximateLastSignInDateTime
        
        ADComputerEnabled = $ADComputer.Enabled
        ADComputerObjectGUID = $ADComputer.ObjectGUID
        ADComputerOSVersion = $ADComputer.OperatingSystemVersion
        ADComputerName = $ADComputer.Name
        ADComputerLastLogonDate = $ADComputer.LastLogonDate
        ADComputerPasswordLastSet = $ADComputer.PasswordLastSet

        IntuneDeviceID = $IntuneDevice.Id
        IntuneDeviceOSVersion = $IntuneDevice.OSVersion
        IntuneDeviceName = $IntuneDevice.DeviceName
        IntuneDeviceRegistrationState = $IntuneDevice.DeviceRegistrationState
        IntuneDeviceUserPrincipalName = $IntuneDevice.UserPrincipalName
    
    }
            
    $DeviceRecords += $DeviceRecord

}

#
# Generate the Output File Path
#

$WorkingDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

$OutputFileName = "StaleDevices-" + $(Get-Date -Format "MM-dd-yyyy-HHmm") + ".csv"

$OutputFilePath = Join-Path -Path $WorkingDirectory -ChildPath $OutputFileName

$DeviceRecords | Export-CSV -Path $OutputFilePath -NoTypeInformation