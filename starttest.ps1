Import-Module -Force .\libs\appfuncs.psm1
Import-Module -Force .\libs\clusterfuncs.psm1
Import-Module -Force .\libs\testfuncs.psm1
Import-Module -Force .\libs\utils.psm1

$testConf = Get-Content .\testconf.json | ConvertFrom-Json
$clusterInfo = ($testConf).ClusterInfo
$appInfo = ($testConf).AppInfo
$ipv4Testcases = ($testConf).IPV4Testcases
$ipv6Testcases = ($testConf).IPV6Testcases

function RunTestcase {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $false)] [bool]$useIPV6 = $false,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $ipVersion = "IPV4"
    if($useIPV6) {
        $ipVersion = "IPV6"
    }
    $tcaseName = $testcase.Name
    Log "Testcase $index Execution Started. [$ipVersion][Testcase : $tcaseName]"
    switch($testcase.Type) {
        "PodToClusterIP" { TestPodToClusterIP -testcase $testcase -appInfo $appInfo -index $index -useIPV6 $useIPV6 }
        "PodToLocalPod" { TestPodToLocalPod -testcase $testcase -appInfo $appInfo -index $index -useIPV6 $useIPV6 }
        "PodToRemotePod" { TestPodToRemotePod -testcase $testcase -appInfo $appInfo -index $index -useIPV6 $useIPV6 }
        "PodToNodePort" { TestPodToNodePort -testcase $testcase -appInfo $appInfo -index $index -useIPV6 $useIPV6 }
        "PodToIngressIP" { TestPodToIngressIP -testcase $testcase -appInfo $appInfo -index $index -useIPV6 $useIPV6 }
        "ExternalToIngressIP" { TestExternalToIngressIP -testcase $testcase -appInfo $appInfo -index $index -useIPV6 $useIPV6 }
        "PodToLocalNode" { TestPodToLocalNode -testcase $testcase -appInfo $appInfo -index $index -useIPV6 $useIPV6 }
        "PodToRemoteNode" { TestPodToRemoteNode -testcase $testcase -appInfo $appInfo -index $index -useIPV6 $useIPV6 }
        "PodToInternet" { TestPodToInternet -testcase $testcase -appInfo $appInfo -index $index -useIPV6 $useIPV6 }
        "PingPodToLocalPod" { TestPingPodToLocalPod -testcase $testcase -appInfo $appInfo -index $index -useIPV6 $useIPV6 }
        "PingPodToRemotePod" { TestPingPodToRemotePod -testcase $testcase -appInfo $appInfo -index $index -useIPV6 $useIPV6 }
        "PingPodToLocalNode" { TestPingPodToLocalNode -testcase $testcase -appInfo $appInfo -index $index -useIPV6 $useIPV6 }
        "PingPodToRemoteNode" { TestPingPodToRemoteNode -testcase $testcase -appInfo $appInfo -index $index -useIPV6 $useIPV6 }
        "PingPodToInternet" { TestPingPodToInternet -testcase $testcase -appInfo $appInfo -index $index -useIPV6 $useIPV6 }
        default {"No Match Found"}
    }
    Log "Testcase $index Execution Completed. [$ipVersion][Testcase : $tcaseName]"
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
    if($testConf.SkipIPV4) {
        Log "Skipping All IPV4 Testcases."
    } else {
        foreach($testcase in $ipv4Testcases) {
            if($testcase.Skip) {
                $tcaseName = $testcase.Name
                Log "Testcase $index skipped. [Testcase : $tcaseName]"
            } else {
                RunTestcase -testcase $testcase -appInfo $appInfo -index $index
            }
            $index++
        }
    }
    if($testConf.SkipIPV6) {
        Log "Skipping All IPV6 Testcases."
    } else {
        foreach($testcase in $ipv6Testcases) {
            if($testcase.Skip) {
                $tcaseName = $testcase.Name
                Log "Testcase $index skipped. [Testcase : $tcaseName]"
            } else {
                RunTestcase -testcase $testcase -appInfo $appInfo -index $index -useIPV6 $true
            }
            $index++
        }
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

