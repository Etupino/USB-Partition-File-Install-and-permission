# Define variables
$FilesDir = "C:\path\to\abc"

# Ensure the directory exists
if (-Not (Test-Path -Path $FilesDir)) {
    Write-Error "The directory $FilesDir does not exist."
    exit
}

# Get all USB drives
$usbDrives = Get-Disk | Where-Object { $_.BusType -eq 'USB' }

Write-Output "USB drives detected: $($usbDrives.Count)"
foreach ($drive in $usbDrives) {
    Write-Output "Drive: $($drive.FriendlyName)"
}

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
    Write-Output "User selected: $selection"
    $disk = $usbDrives[$selection - 1]
    Write-Output "Selected disk: $($disk.FriendlyName)"
} else {
    $disk = $usbDrives[0]
    Write-Output "Single USB drive detected: $($disk.FriendlyName)"
}

# Clear any existing partitions
$disk | Clear-Disk -RemoveData -Confirm:$false

# Initialize the disk
$disk | Initialize-Disk -PartitionStyle MBR

# Create the first partition (FAT32)
$partition1 = New-Partition -DiskNumber $disk.Number -Size 16GB -AssignDriveLetter
$partition1 | Format-Volume -FileSystem FAT32 -NewFileSystemLabel "UPGRADE" -Confirm:$false

# Create the second partition (NTFS)
$partition2 = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter
$partition2 | Format-Volume -FileSystem NTFS -NewFileSystemLabel "BACKUP" -Confirm:$false

# Assign drive letters
$driveLetter1 = $partition1.DriveLetter
$driveLetter2 = $partition2.DriveLetter

# Copy files to