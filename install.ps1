# Run this script to bootstrap entire cluster

Import-Module -Force .\libs\appfuncs.psm1
Import-Module -Force .\libs\clusterfuncs.psm1

$testConf = Get-Content .\testconf.json | ConvertFrom-Json
$clusterInfo = ($testConf).ClusterInfo
$appInfo = ($testConf).AppInfo


$Global:nodePoolName = $clusterInfo.NodePoolName

# Setup Cluster
InstallCluster -clusterInfo $clusterInfo
GetClusterCredentials -clusterInfo $clusterInfo

# Setup Apps
if($appInfo.InstallIPv4Required -or $appInfo.InstallIPv6Required) {
    InstallApps -clusterInfo $clusterInfo -appInfo $appInfo
} else {
    Log "Skipping App Install."
}

Log "Completed."

