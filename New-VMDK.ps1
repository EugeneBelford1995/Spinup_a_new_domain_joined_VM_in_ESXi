Function New-VMDK
{
    Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $ESXi,
         [Parameter(Mandatory=$true)]
         [string]$ESXi_User,
         [Parameter(Mandatory=$true)]
         [string]$ESXi_Password,
         [Parameter(Mandatory=$false, Position=1)]
         [string] $VMName
    )

ssh-keygen -t ed25519 -f ".\id_ed25519" -N '""'
Copy-Item -Path .\id_ed25519* -Destination "$env:USERPROFILE\.ssh\"
Connect-VIServer -Server $ESXi -User $ESXi_User -Password $ESXi_Password
Copy-DatastoreItem -Item ".\id_ed25519.pub" -Destination "vmstore:\ha-datacenter\datastore1\authorized_keys.tmp"
#Make sure SSH is enabled on ESXi
Get-VMHost -Name $ESXi | Get-VMHostService | Where-Object { $_.Key -eq 'TSM-SSH' } | Start-VMHostService -Confirm:$false

# Combine into a clean single-line Linux command (no CRLF hidden characters)
$CommandString = "cd /vmfs/volumes/datastore1/TestTemplate && vmkfstools -i TestTemplate.vmdk -d thin ${VMName}.vmdk && mkdir -p ../${VMName} && mv ${VMName}* ../${VMName}/"

# Pass command directly via argument rather than piped stdin
$ESXiServer = $ESXi_User + "@" + $ESXi
ssh -tt $ESXiServer $CommandString
}