Import-Module -Force .\libs\appfuncs.psm1
Import-Module -Force .\libs\clusterfuncs.psm1
Import-Module -Force .\libs\testfuncs.psm1
Import-Module -Force .\libs\utils.psm1

$testConf = Get-Content .\testconf.json | ConvertFrom-Json
$clusterInfo = ($testConf).ClusterInfo
$appInfo = ($testConf).AppInfo
$testcases = ($testConf).Testcases

function RunTestcase {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $tcaseName = $testcase.Name
    Log "Testcase $index Execution Started. [Testcase : $tcaseName]"
    switch($testcase.Type) {
        "PodToClusterIP" { TestPodToClusterIP -testcase $testcase -appInfo $appInfo -index $index }
        "PodToLocalPod" { TestPodToLocalPod -testcase $testcase -appInfo $appInfo -index $index }
        "PodToRemotePod" { TestPodToRemotePod -testcase $testcase -appInfo $appInfo -index $index }
        "PodToNodePort" { TestPodToNodePort -testcase $testcase -appInfo $appInfo -index $index }
        "PodToIngressIP" { TestPodToIngressIP -testcase $testcase -appInfo $appInfo -index $index }
        "ExternalToIngressIP" { TestExternalToIngressIP -testcase $testcase -appInfo $appInfo -index $index }
        "PodToLocalNode" { TestPodToLocalNode -testcase $testcase -appInfo $appInfo -index $index }
        "PodToRemoteNode" { TestPodToRemoteNode -testcase $testcase -appInfo $appInfo -index $index }
        "PodToInternet" { TestPodToInternet -testcase $testcase -appInfo $appInfo -index $index }
        default {"No Match Found"}
    }
    Log "Testcase $index Execution Completed. [Testcase : $tcaseName]"
}

$Global:nodePoolName = $clusterInfo.NodePoolName

# Setup Cluster
if($clusterInfo.InstallRequired) {
    InstallCluster -clusterInfo $clusterInfo
} else {
    Log "Skipping AKS Cluster Deployment."
}

if($clusterInfo.ResetClusterCreds) {
    GetClusterCredentials -clusterInfo $clusterInfo
}

# Setup Apps
if($appInfo.InstallIPv4Required -or $appInfo.InstallIPv6Required) {
    InstallApps -appInfo $appInfo
} else {
    Log "Skipping App Install."
}

# looping through testcases
$index = 1
Clear-Content $appInfo.LogPath

if($testConf.SkipAllTestcases) {
    Log "Skipping All Testcases."
} else {
    foreach($testcase in $testcases) {
        if($testcase.Skip) {
            $tcaseName = $testcase.Name
            Log "Testcase $index skipped. [Testcase : $tcaseName]"
        } else {
            if($testcase.UseIPV6) {
                if($testConf.SkipIPV6) {
                    Log "Testcase $index skipped. [Testcase : $tcaseName]"
                } else {
                    RunTestcase -testcase $testcase -appInfo $appInfo -index $index
                }
            } else {
                if($testConf.SkipIPV4) {
                    Log "Testcase $index skipped. [Testcase : $tcaseName]"
                } else {
                    RunTestcase -testcase $testcase -appInfo $appInfo -index $index
                }
            }
            
        }
        $index++
    }
}

# Teardown Apps
if($appInfo.UninstallAfterTest) {
    UninstallApps -namespace $appInfo.Namespace
}

# Tear down cluster
if($clusterInfo.UninstallAfterTest) {
    UninstallCluster -clusterInfo $clusterInfo
}

Write-Host " "
Log "TEST RESULTS =========#"
Write-Host " "
Get-Content $appInfo.LogPath

Log "Testcases Completed."

