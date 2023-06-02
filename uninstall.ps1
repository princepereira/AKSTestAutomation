# Run this script to tear down entire cluster

Import-Module -Force .\libs\clusterfuncs.psm1

$testConf = Get-Content .\testconf.json | ConvertFrom-Json
$clusterInfo = ($testConf).ClusterInfo

# Tear down cluster
UninstallCluster -clusterInfo $clusterInfo

Log "Completed."

