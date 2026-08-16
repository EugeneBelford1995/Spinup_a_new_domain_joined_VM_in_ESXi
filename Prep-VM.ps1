Function Prep-VM
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$VMName
    )

$Network = Get-VirtualPortGroup -Name "VM Network" -Standard
$NewVM = New-VM -Name $VMName -MemoryGB 4 -NumCPU 2 -Datastore "datastore1" -GuestId "windows9Server64Guest" -DiskGB 1 -NetworkName $Network
Get-HardDisk -VM $NewVM | Remove-HardDisk -DeletePermanently:$true -Confirm:$false

#Gemini wrote this part, but it works. Basically uses raw API calls to map the vmdk to the VM's IDE 0
#Build the VirtualDisk configuration spec
$VM = Get-VM $VMName
$DiskSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
$DiskChange = New-Object VMware.Vim.VirtualDeviceConfigSpec
$DiskChange.Operation = [VMware.Vim.VirtualDeviceConfigSpecOperation]::add
# Define the Virtual Disk
$Disk = New-Object VMware.Vim.VirtualDisk
$Disk.ControllerKey = 200  # Target IDE Controller 0 (Key 200)
$Disk.UnitNumber = 0     # First drive position on IDE 0
#Set the backing to your existing datastore file
$DiskBacking = New-Object VMware.Vim.VirtualDiskFlatVer2BackingInfo
$DiskBacking.FileName = "[datastore1] TestServerII/TestServerII.vmdk"
$DiskBacking.DiskMode = "persistent"
$Disk.Backing = $DiskBacking
$DiskChange.Device = $Disk
$DiskSpec.DeviceChange += $DiskChange
#Apply changes to the VM
$VM.ExtensionData.ReconfigVM($DiskSpec)

Start-Sleep -Seconds 120

#Gemini wrote this part too. Basically uses raw API calls to mount the VM Tools installer.
#PowerCLI and VMware in general really kinda sucked here. Hyper-V does this a lot easier.
#This part must be run between creating the VM and starting it. 
$NewVM = Get-VM $VMName
# 1. Initialize configuration spec
$Spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$CdSpec = New-Object VMware.Vim.VirtualDeviceConfigSpec
$CdSpec.Operation = [VMware.Vim.VirtualDeviceConfigSpecOperation]::add
# 2. Instantiate a new Virtual CD-ROM Device
$CdDrive = New-Object VMware.Vim.VirtualCdrom
$CdDrive.ControllerKey = 200 # Attach to IDE Controller 0
$CdDrive.UnitNumber = 1     # Place on Unit 1 (Hard disk is on Unit 0)
# 3. Define ISO Backing
$CdBacking = New-Object VMware.Vim.VirtualCdromIsoBackingInfo
$CdBacking.FileName = "[] /usr/lib/vmware/isoimages/windows.iso"
$CdDrive.Backing = $CdBacking
# 4. Set connection flags so Windows mounts it automatically
$CdDrive.Connectable = New-Object VMware.Vim.VirtualDeviceConnectInfo
$CdDrive.Connectable.Connected = $true
$CdDrive.Connectable.StartConnected = $true
# 5. Assign device to spec and reconfigure VM
$CdSpec.Device = $CdDrive
$Spec.DeviceChange += $CdSpec
$NewVM.ExtensionData.ReconfigVM($Spec)
}