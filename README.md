This function requires that:

You have ESXi up & running with a license already

You have a Template VMDK on the ESXi's datastore located at /vmfs/volumes/datastore1/TestTemplate/TestTemplate.vmdk

You have already created an account in AD for the new VM


As long as that's done ahead of time this function:

Creates a VMDK from the template

Creates a VM

maps the VMDK

maps VM Tools

boots the VM

configs the NIC & names the OS

restarts the VM

domain joins it

restarts again

leaves you with a domain joined VM all ready to manage via WinRM

