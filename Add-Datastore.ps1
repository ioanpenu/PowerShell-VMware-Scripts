# Define variables
$vCenterServer = "your-vcenter-server.domain" # Replace with your vCenter Server
$nfsServerBase = "nfs-hostname.domain"        # Replace with your NFS server
$nfsPath = "/nfs/iso"                         # Replace with your NFS path

# Connect to vCenter
Connect-VIServer -Server $vCenterServer 

# Retrieve all datacenters
$datacenters = Get-Datacenter

foreach ($datacenter in $datacenters) {
    # Extract characters 3 to 7 from the datacenter name
    $shortName = $datacenter.Name.Substring(2, 5).ToUpper()

    # Create the datastore name
    $datastoreName = "ISO-$shortName-NEW"

    # Retrieve all clusters in the datacenter
    $clusters = Get-Cluster -Location $datacenter

    foreach ($cluster in $clusters) {
        # Retrieve all hosts in the cluster
        $vmHosts = Get-VMHost -Location $cluster

        foreach ($vmHost in $vmHosts) {
            # Check if the datastore already exists on the host
            $existingDatastore = Get-Datastore -Name $datastoreName -VMHost $vmHost -ErrorAction SilentlyContinue

            if (-not $existingDatastore) {
                try {
                    # Add NFS datastore to the host
                    New-Datastore -Nfs -VMHost $vmHost -Name $datastoreName -NfsHost $nfsServerBase -Path $nfsPath -FileSystemVersion '4.1' -ReadOnly
                    Write-Host "Successfully added datastore '$datastoreName' to host '$($vmHost.Name)'."
                } catch {
                    Write-Host "Failed to add datastore '$datastoreName' to host '$($vmHost.Name)': $($_.Exception.Message)"
                }
            } else {
                Write-Host "Datastore '$datastoreName' already exists on host '$($vmHost.Name)'. Skipping."
            }
        }
    }
}

# Disconnect from vCenter
Disconnect-VIServer -Server $vCenterServer -Confirm:$false
