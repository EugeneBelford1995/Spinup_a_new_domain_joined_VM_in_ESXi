#This almost had to be a function as PowerCLI doesn't support $using:variable
#The ` character escapes variables in the string being passed to the VM so Windows ignores them locally
Function Add-VMToDomain
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$VMName,
        [Parameter(Mandatory=$true)]
        [string]$DomainName,
        [Parameter(Mandatory=$true)]
        [string]$DomainUser,
        [Parameter(Mandatory=$true)]
        [string]$DomainPassword
    )

    # Expand local string variables into script text before passing to ESXi
    $ScriptPayload = "
        netsh advfirewall firewall set rule group='Network Discovery' new enable=Yes
        `$SecPass = ConvertTo-SecureString '$DomainPassword' -AsPlainText -Force
        `$GuestDomainCred = New-Object System.Management.Automation.PSCredential ('$DomainUser', `$SecPass)
        Add-Computer -DomainName '$DomainName' -Credential `$GuestDomainCred -Restart -Force
    "
    Invoke-VMScript -VM $VMName -GuestCredential $InitialCredObject -ScriptType PowerShell -ScriptText $ScriptPayload
}