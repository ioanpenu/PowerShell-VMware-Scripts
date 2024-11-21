# Define variables
$vCenterServer = "your-vcenter-server.domain"  # Replace with your vCenter Server

# Connect to vCenter
Connect-VIServer -Server $vCenterServer 

# Retrieve all datacenters and sort them alphabetically by Name
$datacenters = Get-Datacenter | Sort-Object -Property Name

foreach ($datacenter in $datacenters) {
    # Extract characters 3 to 7 from the datacenter name
    $shortName = $datacenter.Name.Substring(2, 5).ToUpper()

    # Retrieve all datastores in the datacenter
    $datastores = Get-Datastore -Location $datacenter

    foreach ($datastore in $datastores) {
        # Check if the datastore name matches the pattern "ISO-XXXNN-NEU"
        if ($datastore.Name -match "^ISO-[A-Z]{3}\d{2}-NEU$") {
            # Construct the new datastore name
            $newDatastoreName = "ISO-ANSIBLE-$shortName"

            # Prompt for confirmation before renaming this datastore
            $datastoreConfirm = Read-Host "Rename datastore '$($datastore.Name)' to '$newDatastoreName'? (yes/no)"
            if ($datastoreConfirm -match "^(yes|y)$") {
                try {
                    # Rename the datastore
                    Set-Datastore -Datastore $datastore -Name $newDatastoreName
                    Write-Host "Successfully renamed datastore '$($datastore.Name)' to '$newDatastoreName'." -ForegroundColor Green
                } catch {
                    Write-Host "Failed to rename datastore '$($datastore.Name)': $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "Skipped renaming datastore '$($datastore.Name)'." -ForegroundColor Yellow
            }
        } else {
            # Debug: Non-matching datastore
            Write-Host "Datastore '$($datastore.Name)' does not match the pattern." -ForegroundColor Gray
        }
    }
}

# Disconnect from vCenter
Disconnect-VIServer -Server $vCenterServer -Confirm:$false
