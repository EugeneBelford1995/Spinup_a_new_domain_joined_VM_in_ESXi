Write-Host "This function must be run from PowerShell, not PowerShell_ISE, due to the first part New-VMDK which uses SSH and prompts for your password"
Write-Host "Run this function from the folder where all the modules are saved"
Write-Host "Example use: New-VM_from_Template -ESXi 192.168.0.98 -ESXi_User root -ESXi_Password <password> -$VMName TestServer -HostOctet 112 -DomainName test.local -DomainUser Mishky -DomainPassword <password>"
Write-Host "The function assigns the VM's first three octets, subnet mask, GW, and DNS servers based on what your ESXi itself is using"

Function New-VM_from_Template
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$ESXi,
        [Parameter(Mandatory=$true)]
        [string]$ESXi_User,
        [Parameter(Mandatory=$true)]
        [string]$ESXi_Password,
        [Parameter(Mandatory=$true)]
        [string]$VMName,
        [Parameter(Mandatory=$true)]
        [string]$HostOctet,
        [Parameter(Mandatory=$true)]
        [string]$DomainName,
        [Parameter(Mandatory=$true)]
        [string]$DomainUser,
        [Parameter(Mandatory=$true)]
        [string]$DomainPassword
    )

#Create the VM's HD from the template
#User supplies user@IP, for example root@192.168.0.98, and the VMName to give the new VM and its HD.
. .\New-VMDK.ps1
New-VMDK -ESXi $ESXi -ESXi_User $ESXi_User -ESXi_Password $ESXi_Password -VMName $VMName
Start-Sleep -Seconds 360

Connect-VIServer -Server $ESXi -User $ESXi_User -Password $ESXi_Password
Start-Sleep -Seconds 60

. .\Prep-VM.ps1
Prep-VM -VMName $VMName

Start-Sleep -Seconds 60
Start-VM $VMName
Start-Sleep -Seconds 120

. .\Config-NIC.ps1

# VM's initial local admin credentials:
[string]$userName = ".\Administrator"
[string]$userPassword = 'SuperSecureLocalPassword123!@#'
# Convert to SecureString and build PSCredential object
$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
$InitialCredObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

Config-NIC -VMName $VMName -HostOctet $HostOctet -GuestCred $InitialCredObject

. .\Join-Domain.ps1
Add-VMToDomain -VMName $VMName -DomainName $DomainName -DomainUser $DomainUser -DomainPassword $DomainPassword

#Verify
Invoke-VMScript -VM $VMName -GuestCredential $InitialCredObject -ScriptType Powershell -ScriptText {ipconfig /all}
}