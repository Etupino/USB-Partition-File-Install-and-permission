param (
    [switch]$Elevated
)

#Bypass the executionPolicy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force


# Function to check if the current user has administrator privileges
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Check if the script is run with administrative privileges, if not, attempt to elevate
if ((Test-Admin) -eq $false) {
    if ($Elevated) {
        Write-Host "Failed to elevate permissions. Aborting." -ForegroundColor Red
    }
    else {
        Write-Host "Elevating permissions..."
        Start-Process powershell.exe -Verb RunAs -ArgumentList ("-NoProfile", "-NoExit", "-File", "`"$($myinvocation.MyCommand.Definition)`"", "-Elevated")
    }
    exit
}

Write-Host "Running with full privileges"

# Function to display progress bar
function Show-ProgressBar {
    Write-Host "Running..." -NoNewline
    for ($i = 1; $i -le 100; $i++) {
        Write-Progress -Activity "Progress" -Status "$i% Complete" -PercentComplete $i
        Start-Sleep -Milliseconds 250
    }
    Write-Host " Complete!" -ForegroundColor Green
}

# Define variables
$Current_User = ([system.security.Principal.WindowsIdentity]::GetCurrent().Name).split('\')[1]
$FilesDir = "C:\Users\$Current_User\Desktop\501923032"

# Ensure the directory exists
if (-Not (Test-Path -Path $FilesDir)) {
    Write-Error "The directory $FilesDir does not exist."
    exit
}

# Get all USB drives
$usbDrives = Get-Disk | Where-Object { $_.BusType -eq 'USB' }

if ($usbDrives.Count -eq 0) {
    Write-Error "No USB drives detected."
    exit
}

# If there's more than one USB drive, prompt the user to select one
if ($usbDrives.Count -gt 1) {
    Write-Output "Multiple USB drives detected. Please select one:"
    for ($i = 0; $i -lt $usbDrives.Count; $i++) {
        Write-Output "$($i + 1): $($usbDrives[$i].FriendlyName)"
    }
    $selection = Read-Host "Enter the number of the USB drive to use"
    $disk = $usbDrives[$selection - 1]
} else {
    $disk = $usbDrives[0]
}

# Clear any existing partitions
$disk | Clear-Disk -RemoveData -Confirm:$false

# Initialize the disk
$disk | Initialize-Disk -PartitionStyle MBR -erroraction 'silentlycontinue'

# Create the first partition (FAT32)
$partition1 = New-Partition -DiskNumber $disk.Number -Size 16GB -AssignDriveLetter
$partition1 | Format-Volume -FileSystem FAT32 -NewFileSystemLabel "UPGRADE" -Confirm:$false

# Create the second partition (NTFS)
$partition2 = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter
$partition2 | Format-Volume -FileSystem NTFS -NewFileSystemLabel "BACKUP" -Confirm:$false

# Assign drive letters
$driveLetter1 = $partition1.DriveLetter
$driveLetter2 = $partition2.DriveLetter

# Copy files to the first partition
Copy-Item -Path "$FilesDir\*" -Destination "$($driveLetter1):\" -Recurse

# Copy files to the second partition
Copy-Item -Path "$FilesDir\*" -Destination "$($driveLetter2):\" -Recurse

# Set permissions on the second partition
#$acl = Get-Acl -Path "$($driveLetter2):\"
#$acl.SetAccessRuleProtection($true, $false)  # Disable inheritance
#$rule = New-Object

# Set permissions on the second partition
$acl = Get-Acl -Path "$($driveLetter2):\"
$acl.SetAccessRuleProtection($true, $false)  # Disable inheritance
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "ReadAndExecute, ListDirectory, Read", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.SetAccessRule($rule)
Set-Acl -Path "$($driveLetter2):\" -AclObject $acl

Write-Host "USB drive setup complete. FAT32 partition is $driveLetter1 :, NTFS partition is $driveLetter2 :."