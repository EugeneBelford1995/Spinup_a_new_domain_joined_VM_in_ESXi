Function Config-NIC
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$VMName,
        [Parameter(Mandatory=$true)]
        [int]$HostOctet, # e.g., 112
        [Parameter(Mandatory=$true)]
        [pscredential]$GuestCred,
        [Parameter(Mandatory=$false)]
        [string]$ESXiHost = $ESXi
    )

# VM's initial local admin credentials:
[string]$userName = ".\Administrator"
[string]$userPassword = 'SuperSecureLocalPassword123!@#'
# Convert to SecureString and build PSCredential object
$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
$InitialCredObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)
    
#Get the IP scheme from ESXi itself
$GW         = (Get-VMHostNetwork -Server $ESXiHost).VMKernelGateway
$SubnetMask = (Get-VMHostNetworkAdapter -Server $ESXiHost -Name vmk0).SubnetMask
$DNSServers = (Get-VMHostNetwork -Server $ESXiHost).DnsAddress # Returns array of DNS IP strings

#Use the first 3 octets of ESXi's IP + 4th Octet for the new VM 
$SubnetBase = ($ESXiHost.Split('.')[0..2]) -join '.' # "192.168.0"
$TargetIP   = "$SubnetBase.$HostOctet"              # "192.168.0.112"

#Convert Subnet Mask to CIDR Prefix (i.e., "255.255.255.0" -> 24)
$Bytes = $SubnetMask.Split('.') | ForEach-Object { [Convert]::ToString([byte]$_, 2) }
$PrefixLength = ($Bytes -join '').IndexOf('0')
if ($PrefixLength -eq -1) { $PrefixLength = 32 }

#Format DNS Server List into PowerShell Array Syntax string
#Converts @("192.168.0.101", "192.168.0.102") -> "'192.168.0.101','192.168.0.102'"
$FormattedDNS = ($DNSServers | ForEach-Object { "'$_'" }) -join ','

#Build Dynamic Payload via Double-Quoted String Expansion
$ScriptPayload = "
        `$Adapter = Get-NetAdapter | Where-Object { `$_.Status -eq 'Up' } | Select-Object -First 1
        # Configure Static IP and Default Gateway
        New-NetIPAddress -InterfaceAlias `$Adapter.Name -IPAddress '$TargetIP' -PrefixLength $PrefixLength -DefaultGateway '$GW'

        # Assign Dynamic DNS Array from ESXi Host
        Set-DnsClientServerAddress -InterfaceAlias `$Adapter.Name -ServerAddresses @($FormattedDNS)

        # Disable IPv6
        `$NIC = (Get-NetAdapter).InterfaceAlias
        Disable-NetAdapterBinding -InterfaceAlias `$NIC -ComponentID ms_tcpip6

        Install-WindowsFeature -Name 'RSAT' -IncludeAllSubFeature         
        Rename-Computer -NewName '$VMName' -Force
        Restart-Computer -Force
    "

# 6. Execute inside VM over ESXi Hypervisor Layer
Invoke-VMScript -VM $VMName -GuestCredential $GuestCred -ScriptType PowerShell -ScriptText $ScriptPayload
}