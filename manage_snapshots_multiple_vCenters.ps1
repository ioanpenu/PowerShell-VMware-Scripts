
#Date of Creation: 25.12.2023
#Last Modified: 11.01.2025
#Author: Ioan Penu 
#Contact ioanpenu@gmail.com | www.it-react.com 
#Description: Interacts with snapshots on VMware vCenter
#Version: 2

# Import the VMware PowerCLI module
Import-Module VMware.PowerCLI

# Function to login to multiple vCenters
function Login-MultipleVCenters {
    function Login-VCenter {
        param (
            [string]$vcServer,
            [PSCredential]$credential
        )

        try {
            Connect-VIServer -Server $vcServer -Credential $credential -ErrorAction Stop
            [Console]::ForegroundColor = [ConsoleColor]::Green
            Write-Host ("Successfully connected to vCenter server: $vcServer." + [System.Environment]::NewLine)
            [Console]::ResetColor()
        } catch {
            Write-Host "Cannot complete login to $vcServer due to an incorrect user name or password or other issue." -ForegroundColor Red
            throw
        }
    }

    # Clear existing connections
    $global:DefaultVIServer = @()

    # Initial login
    $vcServer = Read-Host "Enter vCenter server"
    $credential = Get-Credential -Message "Enter your vCenter credentials"

    try {
        Login-VCenter -vcServer $vcServer -credential $credential
    } catch {
        Write-Host "Exiting script." -ForegroundColor Red
        exit
    }

    # Prompt for additional vCenters
    while ($true) {
        $response = Read-Host "Would you like to connect to another vCenter? (Yes/No)"

        if ($response -match "(?i)^y(?:es)?$") {
            $additionalVCenter = Read-Host "Enter the FQDN or IP address of the next vCenter"
            $useSameCredentials = Read-Host "Would you like to use the same credentials for $additionalVCenter? (Yes/No)"

            if ($useSameCredentials -match "(?i)^y(?:es)?$") {
                try {
                    Login-VCenter -vcServer $additionalVCenter -credential $credential
                } catch {
                    Write-Host "Failed to connect to vCenter: $additionalVCenter. Skipping to next prompt." -ForegroundColor Yellow
                }
            } elseif ($useSameCredentials -match "(?i)^no?$") {
                $newCredential = Get-Credential -Message "Enter credentials for $additionalVCenter"
                try {
                    Login-VCenter -vcServer $additionalVCenter -credential $newCredential
                } catch {
                    Write-Host "Failed to connect to vCenter: $additionalVCenter. Skipping to next prompt." -ForegroundColor Yellow
                }
            } else {
                Write-Host "Invalid response. Please enter 'Yes' or 'No'." -ForegroundColor Red
            }
        } elseif ($response -match "(?i)^no?$") {
            Write-Host "No additional vCenters to connect. Proceeding to menu." -ForegroundColor Yellow
            break
        } else {
            Write-Host "Invalid response. Please enter 'Yes' or 'No'." -ForegroundColor Red
        }
    }

    Write-Host "Connection process complete." -ForegroundColor Green
}

# Automatically log in to multiple vCenters
Login-MultipleVCenters


# Function to list snapshots with numbers
function List-Snapshots-Numbered {
    $snapshots = Get-VM | Get-Snapshot

    if ($snapshots.Count -eq 0) {
        Write-Host "No snapshots found."
    } else {
        Write-Host "Snapshots:"
        for ($i = 0; $i -lt $snapshots.Count; $i++) {
            Write-Host "$($i + 1). VM: $($snapshots[$i].VM.Name), Snapshot: $($snapshots[$i].Name)"
        }
    }
}

# Function to create a snapshot
function Create-Snapshot {
    $vmName = Read-Host "Enter the name of the VM"
    $vm = Get-VM -Name $vmName

    if ($vm) {
        $snapshotName = Read-Host "Enter the name of the snapshot"
        $snapshotDescription = Read-Host "Enter the description of the snapshot"

        $originalErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        
        New-Snapshot -VM $vm -Name $snapshotName -Description $snapshotDescription
        
        $ErrorActionPreference = $originalErrorActionPreference
        
        Write-Host "Snapshot $($snapshotName) created for VM $($vm.Name)."
    } else {
        Write-Host "VM $($vmName) not found."
    }
}

# Function to restore a snapshot by number
function Restore-Snapshot-By-Number {
    $snapshots = Get-VM | Get-Snapshot

    if ($snapshots.Count -eq 0) {
        Write-Host "No snapshots found."
        return
    }

    List-Snapshots-Numbered

    $snapshotNumber = Read-Host "Enter the number of the snapshot to restore"

    if ([int]$snapshotNumber -ge 1 -and [int]$snapshotNumber -le $snapshots.Count) {
        $snapshot = $snapshots[$snapshotNumber - 1]
        $confirmation = Read-Host "Are you sure you want to restore snapshot $($snapshot.Name) for VM $($snapshot.VM.Name)? (Y/N)"
        if ($confirmation -eq "Y" -or $confirmation -eq "y") {
            Set-VM -VM $snapshot.VM -Snapshot $snapshot
            Write-Host "Restored snapshot $($snapshot.Name) for VM $($snapshot.VM.Name)."
        } else {
            Write-Host "Restoration cancelled."
        }
    } else {
        Write-Host "Invalid snapshot number."
    }
}

# Function to delete a snapshot by number
function Delete-Snapshot-By-Number {
    List-Snapshots-Numbered
    $snapshotNumber = Read-Host "Enter the number of the snapshot to delete"

    if ([int]::TryParse($snapshotNumber, [ref]0)) {
        $snapshotNumber = [int]$snapshotNumber
        $snapshots = Get-VM | Get-Snapshot

        if ($snapshotNumber -ge 1 -and $snapshotNumber -le $snapshots.Count) {
            $snapshotToDelete = $snapshots[$snapshotNumber - 1]
            Write-Host "You've chosen to delete the snapshot $($snapshotToDelete.Name) for VM $($snapshotToDelete.VM.Name)."

            $confirmation = Read-Host "Are you sure you want to delete this snapshot? (Y/N)"
            if ($confirmation -eq "Y" -or $confirmation -eq "y") {
                $originalErrorActionPreference = $ErrorActionPreference
                $ErrorActionPreference = "SilentlyContinue"
                Remove-Snapshot -Snapshot $snapshotToDelete -Confirm:$false
                $ErrorActionPreference = $originalErrorActionPreference
                Write-Host "Snapshot $($snapshotToDelete.Name) deleted."
            } else {
                Write-Host "Snapshot deletion cancelled."
            }
        } else {
            Write-Host "Invalid snapshot number."
        }
    } else {
        Write-Host "Invalid input. Please enter a valid number."
    }
}

# Function to export snapshots to a file
function Export-Snapshots {
    $snapshots = Get-VM | Get-Snapshot

    if ($snapshots.Count -eq 0) {
        Write-Host "No snapshots found to export."
        return
    }

    $exportFileName = "export_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $snapshotsData = @()

    foreach ($snapshot in $snapshots) {
        $snapshotData = [PSCustomObject]@{
            VMName = $snapshot.VM.Name
            SnapshotName = $snapshot.Name
        }
        $snapshotsData += $snapshotData
    }

    $snapshotsData | Export-Csv -Path $exportFileName -NoTypeInformation
    Write-Host "Snapshots exported to $($exportFileName)."
}

# Function to import snapshots from a CSV file and prompt for creation
function Import-File-And-Create-Snapshots {
    $importFile = Read-Host "Enter the path to the import CSV file"
    
    if (-not (Test-Path $importFile)) {
        Write-Host "Import file not found."
        return
    }

    $snapshotsData = Import-Csv -Path $importFile

    if ($snapshotsData.Count -eq 0) {
        Write-Host "No snapshots found in the import file."
        return
    }

    Write-Host "Snapshots to create from the import file:"
    foreach ($snapshotData in $snapshotsData) {
        Write-Host "VM: $($snapshotData.VMName), Snapshot: $($snapshotData.SnapshotName)"
    }

    $confirmation = Read-Host "Are you sure you want to create these snapshots? (Y/N)"

    if ($confirmation -eq "Y" -or $confirmation -eq "y") {
        foreach ($snapshotData in $snapshotsData) {
            $vmName = $snapshotData.VMName
            $vm = Get-VM -Name $vmName

            if ($vm) {
                $snapshotName = $snapshotData.SnapshotName
                $snapshotDescription = "Imported snapshot from file"
                New-Snapshot -VM $vm -Name $snapshotName -Description $snapshotDescription
                Write-Host "Snapshot $($snapshotName) created for VM $($vmName)."
            } else {
                Write-Host "VM $($vmName) not found."
            }
        }
    } else {
        Write-Host "Creation cancelled."
    }
}


# Function to import snapshots from a CSV file and prompt for deletion
function Import-File-And-Delete-Snapshots {
    $importFile = Read-Host "Enter the path to the import CSV file"
    
    if (-not (Test-Path $importFile)) {
        Write-Host "Import file not found."
        return
    }

    $snapshotsData = Import-Csv -Path $importFile

    if ($snapshotsData.Count -eq 0) {
        Write-Host "No snapshots found in the import file."
        return
    }

    Write-Host "Snapshots to delete from the import file:"
    foreach ($snapshotData in $snapshotsData) {
        Write-Host "VM: $($snapshotData.VMName), Snapshot: $($snapshotData.SnapshotName)"
    }

    $confirmation = Read-Host "Are you sure you want to delete these snapshots? (Y/N)"

    if ($confirmation -eq "Y" -or $confirmation -eq "y") {
        foreach ($snapshotData in $snapshotsData) {
            $vmName = $snapshotData.VMName
            $snapshotName = $snapshotData.SnapshotName
            $vm = Get-VM -Name $vmName

            if ($vm) {
                $snapshot = Get-Snapshot -VM $vm -Name $snapshotName
                if ($snapshot) {
                    Remove-Snapshot -Snapshot $snapshot -Confirm:$false
                    Write-Host "Snapshot $($snapshotName) deleted for VM $($vmName)."
                } else {
                    Write-Host "Snapshot $($snapshotName) not found for VM $($vmName)."
                }
            } else {
                Write-Host "VM $($vmName) not found."
            }
        }
    } else {
        Write-Host "Deletion cancelled."
    }
}

# Main loop
$continueLoop = $true
while ($continueLoop) {
    Write-Host "Choose an action:"
    Write-Host " (L)ist snapshots"
    Write-Host " (C)reate snapshot"
    Write-Host " (R)estore snapshot"
    Write-Host " (D)elete snapshot"
    Write-Host " (E)xport snapshots to file"
    Write-Host " (I)mport file and create snapshots"
    Write-Host " i(M)port file and delete snapshots"
    Write-Host " (Q)uit"

    $action = Read-Host -Prompt "Enter your choice"

    switch ($action.ToUpper()) {
        "C" {
            Create-Snapshot
        }
        "L" {
            List-Snapshots-Numbered
        }
        "R" {
            Restore-Snapshot-By-Number
        }
        "D" {
            Delete-Snapshot-By-Number
        }
        "E" {
            Export-Snapshots
        }
        "I" {
            Import-File-And-Create-Snapshots
        }
        "M" {
            Import-File-And-Delete-Snapshots
        }
        "Q" {
            Write-Host "Exiting script."
            Disconnect-VIServer -Server $global:DefaultVIServer -Confirm:$false
            $continueLoop = $false
            break
        }
        default {
            Write-Host "Invalid choice."
        }
    }
}
