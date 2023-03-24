Import-Module -Force .\libs\utils.psm1

$ActionScaleTo = "ScaleTo"
$ActionSleep = "Sleep"
$ActionStartTcpClient = "StartTcpClient"
$ActionFailReadinessProbe = "FailReadinessProbe"
$ActionPassReadinessProbe = "PassReadinessProbe"

function TestPodToClusterIP {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    
    if(!(ScalePods -testcase $testcase -appInfo $appInfo -index $index)) {
        return $false
    }

    Log "Pods"
    kubectl get pods -o wide -n $appInfo.Namespace

    $serviceName = $appInfo.ETPClusterServiceName
    $servicePort = $appInfo.ETPClusterServicePort
    if($testcase.ServiceType -eq "ETPLocal") {
        $serviceName = $appInfo.ETPLocalServiceName
        $servicePort = $appInfo.ETPLocalServicePort
    }

    if($useIPV6) {
        $serviceName = $appInfo.ETPClusterServiceNameIPV6
        $servicePort = $appInfo.ETPClusterServicePortIPV6
        if($testcase.ServiceType -eq "ETPLocal") {
            $serviceName = $appInfo.ETPLocalServiceNameIPV6
            $servicePort = $appInfo.ETPLocalServicePortIPV6
        }
    }
    
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName

    if($testcase.DnsName -and $testcase.DnsName -ne "") {
        $clusterIP = $testcase.DnsName
    } else {
        $clusterIP = GetClusterIP -namespace $appInfo.Namespace -serviceName $serviceName
    }

    if(($testcase.Actions) -and ($testcase.Actions).Count -gt 0) {
        $result = RunActions -testcase $testcase -appInfo $appInfo -clientName $clientName -ipAddress $clusterIP -servicePort $servicePort -useIPV6 $useIPV6 -index $index
    } else {
        Log "Start TCP Connection to $clusterIP : $servicePort "
        $result = kubectl exec $clientName -n $appInfo.Namespace -- client -i $clusterIP -p $servicePort -c $testcase.ConnectionCount -r $testcase.RequestsPerConnection -d $testcase.TimeBtwEachRequestInMs
    }
    
    $conCount = $testcase.ConnectionCount
    $expectedResult = "ConnectionsSucceded:$conCount, ConnectionsFailed:0"
    if($testcase.ExpectedResult -and ($testcase.ExpectedResult -ne "")) {
        $expectedResult = $testcase.ExpectedResult
    }
    $tcaseName = NewTestCaseName -testcaseName $testcase.Name -serviceIP $clusterIP -servicePort $servicePort
    LogResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $tcaseName -index $index -expectedResult $expectedResult -actualResult $result[$result.Count-1]
}

function TestPodToNodePort {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
   
    if(!(ScalePods -testcase $testcase -appInfo $appInfo -index $index)) {
        return $false
    }

    Log "Pods"
    kubectl get pods -o wide -n $appInfo.Namespace

    $serviceName = $appInfo.ETPClusterServiceName
    if($testcase.ServiceType -eq "ETPLocal") {
        $serviceName = $appInfo.ETPLocalServiceName
    }

    if($useIPV6) {
        $serviceName = $appInfo.ETPClusterServiceNameIPV6
        if($testcase.ServiceType -eq "ETPLocal") {
            $serviceName = $appInfo.ETPLocalServiceNameIPV6
        }
    }

    Log "Start TCP Connection"
    $nodePort = GetNodePort -namespace $appInfo.Namespace -serviceName $serviceName
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $nodeIPs = GetNodeIPs -useIPV6 $useIPV6
    foreach($nodeIP in $nodeIPs) {
        $result = kubectl exec $clientName -n $appInfo.Namespace -- client -i $nodeIP -p $nodePort -c $testcase.ConnectionCount -r $testcase.RequestsPerConnection -d $testcase.TimeBtwEachRequestInMs
        $conCount = $testcase.ConnectionCount
        $expectedResult = "ConnectionsSucceded:$conCount, ConnectionsFailed:0"
        $newIndex = "$index [$nodeIP :$nodePort]"
        $tcaseName = NewTestCaseName -testcaseName $testcase.Name -serviceIP $nodeIP -servicePort $nodePort
        LogResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $tcaseName -index $newIndex -expectedResult $expectedResult -actualResult $result[$result.Count-1]
    }
}

function TestPodToIngressIP {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )

    if(!(ScalePods -testcase $testcase -appInfo $appInfo -index $index)) {
        return $false
    }

    Log "Pods"
    kubectl get pods -o wide -n $appInfo.Namespace

    $serviceName = $appInfo.ETPClusterServiceName
    $servicePort = $appInfo.ETPClusterServicePort
    if($testcase.ServiceType -eq "ETPLocal") {
        $serviceName = $appInfo.ETPLocalServiceName
        $servicePort = $appInfo.ETPLocalServicePort
    }

    if($useIPV6) {
        $serviceName = $appInfo.ETPClusterServiceNameIPV6
        $servicePort = $appInfo.ETPClusterServicePortIPV6
        if($testcase.ServiceType -eq "ETPLocal") {
            $serviceName = $appInfo.ETPLocalServiceNameIPV6
            $servicePort = $appInfo.ETPLocalServicePortIPV6
        }
    }

    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $ingressIP = GetIngressIP -namespace $appInfo.Namespace -serviceName $serviceName

    if(($testcase.Actions) -and ($testcase.Actions).Count -gt 0) {
        $result = RunActions -testcase $testcase -appInfo $appInfo -clientName $clientName -ipAddress $ingressIP -servicePort $servicePort -useIPV6 $useIPV6 -index $index
    } else {
        Log "Start TCP Connection to $ingressIP : $servicePort "
        $result = kubectl exec $clientName -n $appInfo.Namespace -- client -i $ingressIP -p $servicePort -c $testcase.ConnectionCount -r $testcase.RequestsPerConnection -d $testcase.TimeBtwEachRequestInMs
    }

    $conCount = $testcase.ConnectionCount
    $expectedResult = "ConnectionsSucceded:$conCount, ConnectionsFailed:0"
    if($testcase.ExpectedResult -and ($testcase.ExpectedResult -ne "")) {
        $expectedResult = $testcase.ExpectedResult
    }
    $tcaseName = NewTestCaseName -testcaseName $testcase.Name -serviceIP $ingressIP -servicePort $servicePort
    LogResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $tcaseName -index $index -expectedResult $expectedResult -actualResult $result[$result.Count-1]
}

function TestExternalToIngressIP {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    
    if(!(ScalePods -testcase $testcase -appInfo $appInfo -index $index)) {
        return $false
    }

    Log "Pods"
    kubectl get pods -o wide -n $appInfo.Namespace

    $serviceName = $appInfo.ETPClusterServiceName
    $servicePort = $appInfo.ETPClusterServicePort
    if($testcase.ServiceType -eq "ETPLocal") {
        $serviceName = $appInfo.ETPLocalServiceName
        $servicePort = $appInfo.ETPLocalServicePort
    }

    if($useIPV6) {
        $serviceName = $appInfo.ETPClusterServiceNameIPV6
        $servicePort = $appInfo.ETPClusterServicePortIPV6
        if($testcase.ServiceType -eq "ETPLocal") {
            $serviceName = $appInfo.ETPLocalServiceNameIPV6
            $servicePort = $appInfo.ETPLocalServicePortIPV6
        }
    }

    $ingressIP = GetIngressIP -namespace $appInfo.Namespace -serviceName $serviceName

    if(($testcase.Actions) -and ($testcase.Actions).Count -gt 0) {
        $result = RunActions -testcase $testcase -appInfo $appInfo -clientName $clientName -ipAddress $ingressIP -servicePort $servicePort -useIPV6 $useIPV6 -extClient $true -index $index
    } else {
        Log "Start TCP Connection to $ingressIP : $servicePort "
        $result = bin\client.exe -i $ingressIP -p $servicePort -c $testcase.ConnectionCount -r $testcase.RequestsPerConnection -d $testcase.TimeBtwEachRequestInMs
    }

    $result = bin\client.exe -i $ingressIP -p $servicePort -c $testcase.ConnectionCount -r $testcase.RequestsPerConnection -d $testcase.TimeBtwEachRequestInMs
    $conCount = $testcase.ConnectionCount
    $expectedResult = "ConnectionsSucceded:$conCount, ConnectionsFailed:0"
    if($testcase.ExpectedResult -and ($testcase.ExpectedResult -ne "")) {
        $expectedResult = $testcase.ExpectedResult
    }
    $tcaseName = NewTestCaseName -testcaseName $testcase.Name -serviceIP $ingressIP -servicePort $servicePort
    LogResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $tcaseName -index $index -expectedResult $expectedResult -actualResult $result[$result.Count-1]
}

function TestPodToLocalPod {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    MakeEnoughPodsForPodToPodTesting -appInfo $appInfo
    $localPodIP = GetLocalServerPodIP -namespace $appInfo.Namespace -clientDeploymentName $appInfo.ClientDeploymentName -serverDeploymentName $appInfo.ServerDeploymentName -useIPV6 $useIPV6
    $internalPort = $appInfo.InternalPort
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    Log "Start TCP Connection"
    $result = kubectl exec $clientName -n $appInfo.Namespace -- client -i $localPodIP -p $internalPort -c $testcase.ConnectionCount -r $testcase.RequestsPerConnection -d $testcase.TimeBtwEachRequestInMs
    $conCount = $testcase.ConnectionCount
    $expectedResult = "ConnectionsSucceded:$conCount, ConnectionsFailed:0"
    $tcaseName = NewTestCaseName -testcaseName $testcase.Name -serviceIP $localPodIP -servicePort $internalPort
    LogResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $tcaseName -index $index -expectedResult $expectedResult -actualResult $result[$result.Count-1]
}

function TestPingPodToLocalPod {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    MakeEnoughPodsForPodToPodTesting -appInfo $appInfo
    $localPodIP = GetLocalServerPodIP -namespace $appInfo.Namespace -clientDeploymentName $appInfo.ClientDeploymentName -serverDeploymentName $appInfo.ServerDeploymentName -useIPV6 $useIPV6
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    Log "Start Ping Test to $localPodIP"
    if($useIPV6) {
        $result = kubectl exec $clientName -n $appInfo.Namespace -- ping -6 $localPodIP
    } else {
        $result = kubectl exec $clientName -n $appInfo.Namespace -- ping $localPodIP
    }

    $pingTestSuccess = !(($result | findstr "loss").Contains("100% loss"))
    $pingTestMessage = "Ping from $clientName to $localPodIP is Success : $pingTestSuccess."
    LogPingResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $testcase.Name -index $index -result $pingTestMessage
}

function TestPingPodToRemotePod {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    MakeEnoughPodsForPodToPodTesting -appInfo $appInfo
    $remotePodIP = GetRemoteServerPodIP -namespace $appInfo.Namespace -clientDeploymentName $appInfo.ClientDeploymentName -serverDeploymentName $appInfo.ServerDeploymentName -useIPV6 $useIPV6
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    Log "Start Ping Test to $remotePodIP"
    if($useIPV6) {
        $result = kubectl exec $clientName -n $appInfo.Namespace -- ping -6 $remotePodIP
    } else {
        $result = kubectl exec $clientName -n $appInfo.Namespace -- ping $remotePodIP
    }

    $pingTestSuccess = !(($result | findstr "loss").Contains("100% loss"))
    $pingTestMessage = "Ping from $clientName to $remotePodIP is Success : $pingTestSuccess."
    LogPingResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $testcase.Name -index $index -result $pingTestMessage
}

function TestPodToLocalNode {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $nodeName = GetNodeNameFromPodName -namespace $appInfo.Namespace -podName $clientName
    $localNodeIP = GetLocalNodeIP -nodeName $nodeName -useIPV6 $useIPV6
    Log "Start Test-NetConnection"
    $result = kubectl exec $clientName -n $appInfo.Namespace -- powershell -ExecutionPolicy Unrestricted -command Test-NetConnection -RemoteAddress $localNodeIP | findstr "Succeeded"
    $tcaseName = $testcase.Name
    $tcaseName = "$tcaseName [LocalNodeIP:$localNodeIP]"
    LogPingResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $tcaseName -index $index -result $result
}

function TestPingPodToLocalNode {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $nodeName = GetNodeNameFromPodName -namespace $appInfo.Namespace -podName $clientName
    $localNodeIP = GetLocalNodeIP -nodeName $nodeName -useIPV6 $useIPV6

    Log "Start Ping Test to $localNodeIP"
    if($useIPV6) {
        $result = kubectl exec $clientName -n $appInfo.Namespace -- ping -6 $localNodeIP
    } else {
        $result = kubectl exec $clientName -n $appInfo.Namespace -- ping $localNodeIP
    }

    $pingTestSuccess = !(($result | findstr "loss").Contains("100% loss"))
    $pingTestMessage = "Ping from $clientName to $localNodeIP is Success : $pingTestSuccess."
    LogPingResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $testcase.Name -index $index -result $pingTestMessage
}

function TestPodToRemoteNode {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $nodeName = GetNodeNameFromPodName -namespace $appInfo.Namespace -podName $clientName
    $remoteNodeIP = GetRemoteNodeIP -nodeName $nodeName -useIPV6 $useIPV6
    Log "Start Test-NetConnection"
    $result = kubectl exec $clientName -n $appInfo.Namespace -- powershell -ExecutionPolicy Unrestricted -command Test-NetConnection -RemoteAddress $remoteNodeIP | findstr "Succeeded"
    $tcaseName = $testcase.Name
    $tcaseName = "$tcaseName [RemoteNodeIP:$remoteNodeIP]"
    LogPingResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $tcaseName -index $index -result $result
}

function TestPingPodToRemoteNode {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $nodeName = GetNodeNameFromPodName -namespace $appInfo.Namespace -podName $clientName
    $remoteNodeIP = GetRemoteNodeIP -nodeName $nodeName -useIPV6 $useIPV6

    Log "Start Ping Test to $remoteNodeIP"
    if($useIPV6) {
        $result = kubectl exec $clientName -n $appInfo.Namespace -- ping -6 $remoteNodeIP
    } else {
        $result = kubectl exec $clientName -n $appInfo.Namespace -- ping $remoteNodeIP
    }

    $pingTestSuccess = !(($result | findstr "loss").Contains("100% loss"))
    $pingTestMessage = "Ping from $clientName to $localNodeIP is Success : $pingTestSuccess."
    LogPingResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $testcase.Name -index $index -result $pingTestMessage
}

function TestPodToInternet {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $remoteAddr = "bing.com"
    if($testcase.RemoteAddress -ne "") {
        $remoteAddr = $testcase.RemoteAddress
    }

    $tcaseName = NewTestCaseName -testcaseName $testcase.Name -serviceIP $remoteAddr

    $ipVersion = "IPV4"
    if($useIPV6) {
        $ipVersion = "IPV6"
    }

    $dnsResolved = kubectl exec $clientName -n $appInfo.Namespace -- powershell -command "Resolve-DnsName $remoteAddr | Select-Object -ExpandProperty IPAddress"

    if(!($dnsResolved)) {
        $result = "[FAILED] Testcase $index : [$ipVersion][$tcaseName] - Result: DNS resolution to $remoteAddr failed"
        Log $result
        Add-content $appInfo.LogPath -value $result
        return $false
    }

    if($useIPV6) {
        $ipv6Addr = ""
        foreach($address in $dnsResolved) {
            if($address.Contains(":")) {
                $ipv6Addr = $address
                break
            }
        }
        if($ipv6Addr -eq "") {
            $availableAddresses = $dnsResolved
            $result = "[FAILED] Testcase $index : [$ipVersion][$tcaseName] - Result: No IPV6 address for $remoteAddr found. Available addresses : $availableAddresses "
            Log $result
            Add-content $appInfo.LogPath -value $result
            return $false
        }
        $remoteAddr = $ipv6Addr
    }

    Log "Start Test-NetConnection to $remoteAddr"
    $result = kubectl exec $clientName -n $appInfo.Namespace -- powershell -ExecutionPolicy Unrestricted -command Test-NetConnection -Port 80 -RemoteAddress $remoteAddr | findstr "Succeeded"
    LogPingResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $tcaseName -index $index -result $result
}

function TestPingPodToInternet {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName

    $remoteAddr = "bing.com"
    if($testcase.RemoteAddress -ne "") {
        $remoteAddr = $testcase.RemoteAddress
    }

    Log "Start Ping Test to $remoteAddr"
    if($useIPV6) {
        $result = kubectl exec $clientName -n $appInfo.Namespace -- ping -6 $remoteAddr
    } else {
        $result = kubectl exec $clientName -n $appInfo.Namespace -- ping $remoteAddr
    }

    $pingTestSuccess = !(($result | findstr "loss").Contains("100% loss"))
    $pingTestMessage = "Ping from $clientName to $localNodeIP is Success : $pingTestSuccess."
    LogPingResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $testcase.Name -index $index -result $pingTestMessage
}

function TestPodToRemotePod {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    MakeEnoughPodsForPodToPodTesting -appInfo $appInfo
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $remotePodIP = GetRemoteServerPodIP -namespace $appInfo.Namespace -clientDeploymentName $appInfo.ClientDeploymentName -serverDeploymentName $appInfo.ServerDeploymentName -useIPV6 $useIPV6
    $internalPort = $appInfo.InternalPort
    Log "Start TCP Connection"
    $result = kubectl exec $clientName -n $appInfo.Namespace -- client -i $remotePodIP -p $internalPort -c $testcase.ConnectionCount -r $testcase.RequestsPerConnection -d $testcase.TimeBtwEachRequestInMs
    $conCount = $testcase.ConnectionCount
    $expectedResult = "ConnectionsSucceded:$conCount, ConnectionsFailed:0"
    $tcaseName = NewTestCaseName -testcaseName $testcase.Name -serviceIP $remotePodIP -servicePort $internalPort
    LogResult -logPath $appInfo.LogPath -useIPV6 $useIPV6 -testcaseName $tcaseName -index $index -expectedResult $expectedResult -actualResult $result[$result.Count-1]
}

function TestPingNodeToRemoteNode {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $nodeName = GetNodeNameFromPodName -namespace $appInfo.Namespace -podName $clientName
    $clientHpc = GetPodNameFromNode -namespace $appInfo.HpcNamespace -nodeName $nodeName -deploymentName $appInfo.HpcDaemonsetName
    $remoteNodeIP = GetRemoteNodeIP -nodeName $nodeName -useIPV6 $useIPV6

    Log "Start Ping Test to $remoteNodeIP"
    if($useIPV6) {
        $result = kubectl exec $clientHpc -n $appInfo.HpcNamespace -- powershell -ExecutionPolicy Unrestricted -command ping -6 $remoteNodeIP
    } else {
        $result = kubectl exec $clientHpc -n $appInfo.HpcNamespace -- powershell -ExecutionPolicy Unrestricted -command ping $remoteNodeIP
    }

    $pingTestSuccess = !(($result | findstr "loss").Contains("100% loss"))
    $pingTestMessage = "Ping from $clientName to $localNodeIP is Success : $pingTestSuccess."
    $tcaseName = NewTestCaseName -testcaseName $testcase.Name -serviceIP $remoteNodeIP
    LogPingResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $tcaseName -index $index -result $pingTestMessage
}

function TestPingNodeToInternet {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )

    $hpcPodNames = GetAllPodNames -namespace $appInfo.HpcNamespace -deploymentName $appInfo.HpcDaemonsetName

    $remoteAddress = "bing.com"
    if($remoteAddress -and $testcase.RemoteAddress -ne "") {
        $remoteAddress = $testcase.RemoteAddress
    }

    foreach($hpcPodName in $hpcPodNames) {

        $nodeName = GetNodeNameFromPodName -namespace $appInfo.HpcNamespace -podName $hpcPodName
        Log "Start Ping from Node [$nodeName] to Internet [$remoteAddress]"

        if($useIPV6) {
            $result = kubectl exec $hpcPodName -n $appInfo.HpcNamespace -- powershell -ExecutionPolicy Unrestricted -command ping -6 $remoteAddress
        } else {
            $result = kubectl exec $hpcPodName -n $appInfo.HpcNamespace -- powershell -ExecutionPolicy Unrestricted -command ping $remoteAddress
        }

        $pingTestSuccess = !(($result | findstr "loss").Contains("100% loss"))
        $pingTestMessage = "Ping from $nodeName [HPC: $hpcPodName] to Internet [$remoteAddress] is Success : $pingTestSuccess."
        $direction = "$nodeName -> $remoteAddress"
        $tcaseName = NewTestCaseName -testcaseName $testcase.Name -serviceIP $direction
        $tcaseName = "[Node:$nodeName]$tcaseName"
        LogPingResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $tcaseName -index $index -result $pingTestMessage

    }

}

function TestPingNodeToLocalPod {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $nodeName = GetNodeNameFromPodName -namespace $appInfo.Namespace -podName $clientName
    $clientHpc = GetPodNameFromNode -namespace $appInfo.HpcNamespace -nodeName $nodeName -deploymentName $appInfo.HpcDaemonsetName
    $localPodIP = GetLocalServerPodIP -namespace $appInfo.Namespace -clientDeploymentName $appInfo.ClientDeploymentName -serverDeploymentName $appInfo.ServerDeploymentName -useIPV6 $useIPV6

    Log "Start Ping Test to $localPodIP"
    if($useIPV6) {
        $result = kubectl exec $clientHpc -n $appInfo.HpcNamespace -- powershell -ExecutionPolicy Unrestricted -command ping -6 $localPodIP
    } else {
        $result = kubectl exec $clientHpc -n $appInfo.HpcNamespace -- powershell -ExecutionPolicy Unrestricted -command ping $localPodIP
    }

    $pingTestSuccess = !(($result | findstr "loss").Contains("100% loss"))
    $pingTestMessage = "Ping from $clientName to $localPodIP is Success : $pingTestSuccess."
    $tcaseName = NewTestCaseName -testcaseName $testcase.Name -serviceIP $localPodIP
    LogPingResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $tcaseName -index $index -result $pingTestMessage
}

function TestNodeToLocalPod {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $nodeName = GetNodeNameFromPodName -namespace $appInfo.Namespace -podName $clientName
    $clientHpc = GetPodNameFromNode -namespace $appInfo.HpcNamespace -nodeName $nodeName -deploymentName $appInfo.HpcDaemonsetName
    $podIP = GetLocalServerPodIP -namespace $appInfo.Namespace -clientDeploymentName $appInfo.ClientDeploymentName -serverDeploymentName $appInfo.ServerDeploymentName -useIPV6 $useIPV6
    $internalPort = $appInfo.InternalPort

    Log "Start TCP Connection to $podIP : $internalPort"
    $result = kubectl exec $clientHpc -n $appInfo.HpcNamespace -- C:\k\client -i $podIP -p $internalPort -c $testcase.ConnectionCount -r $testcase.RequestsPerConnection -d $testcase.TimeBtwEachRequestInMs
    $conCount = $testcase.ConnectionCount
    $expectedResult = "ConnectionsSucceded:$conCount, ConnectionsFailed:0"
    $tcaseName = NewTestCaseName -testcaseName $testcase.Name -serviceIP $podIP -servicePort $internalPort
    LogResult -logPath $appInfo.LogPath -useIPV6 $useIPV6 -testcaseName $tcaseName -index $index -expectedResult $expectedResult -actualResult $result[$result.Count-1]
}

function TestNodeToRemotePod {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $nodeName = GetNodeNameFromPodName -namespace $appInfo.Namespace -podName $clientName
    $clientHpc = GetPodNameFromNode -namespace $appInfo.HpcNamespace -nodeName $nodeName -deploymentName $appInfo.HpcDaemonsetName
    $remotePodIP = GetRemoteServerPodIP -namespace $appInfo.Namespace -clientDeploymentName $appInfo.ClientDeploymentName -serverDeploymentName $appInfo.ServerDeploymentName -useIPV6 $useIPV6
    $internalPort = $appInfo.InternalPort

    Log "Start TCP Connection to $remotePodIP : $internalPort"
    $result = kubectl exec $clientHpc -n $appInfo.HpcNamespace -- C:\k\client -i $remotePodIP -p $internalPort -c $testcase.ConnectionCount -r $testcase.RequestsPerConnection -d $testcase.TimeBtwEachRequestInMs
    $conCount = $testcase.ConnectionCount
    $expectedResult = "ConnectionsSucceded:$conCount, ConnectionsFailed:0"
    $tcaseName = NewTestCaseName -testcaseName $testcase.Name -serviceIP $remotePodIP -servicePort $internalPort
    LogResult -logPath $appInfo.LogPath -useIPV6 $useIPV6 -testcaseName $tcaseName -index $index -expectedResult $expectedResult -actualResult $result[$result.Count-1]
}

function TestNodeToClusterIP {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    
    if(!(ScalePods -testcase $testcase -appInfo $appInfo -index $index)) {
        return $false
    }

    Log "Pods"
    kubectl get pods -o wide -n $appInfo.Namespace

    $serviceName = $appInfo.ETPClusterServiceName
    $servicePort = $appInfo.ETPClusterServicePort
    if($testcase.ServiceType -eq "ETPLocal") {
        $serviceName = $appInfo.ETPLocalServiceName
        $servicePort = $appInfo.ETPLocalServicePort
    }

    if($useIPV6) {
        $serviceName = $appInfo.ETPClusterServiceNameIPV6
        $servicePort = $appInfo.ETPClusterServicePortIPV6
        if($testcase.ServiceType -eq "ETPLocal") {
            $serviceName = $appInfo.ETPLocalServiceNameIPV6
            $servicePort = $appInfo.ETPLocalServicePortIPV6
        }
    }
    
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $nodeName = GetNodeNameFromPodName -namespace $appInfo.Namespace -podName $clientName
    $clientHpc = GetPodNameFromNode -namespace $appInfo.HpcNamespace -nodeName $nodeName -deploymentName $appInfo.HpcDaemonsetName

    if($testcase.DnsName -and $testcase.DnsName -ne "") {
        $clusterIP = $testcase.DnsName
    } else {
        $clusterIP = GetClusterIP -namespace $appInfo.Namespace -serviceName $serviceName
    }

    if(($testcase.Actions) -and ($testcase.Actions).Count -gt 0) {
        $result = RunActions -testcase $testcase -appInfo $appInfo -clientName $clientHpc -ipAddress $clusterIP -servicePort $servicePort -useIPV6 $useIPV6 -index $index
    } else {
        Log "Start TCP Connection to $clusterIP : $servicePort "
        $result = kubectl exec $clientHpc -n $appInfo.HpcNamespace -- client -i $clusterIP -p $servicePort -c $testcase.ConnectionCount -r $testcase.RequestsPerConnection -d $testcase.TimeBtwEachRequestInMs
    }
    
    $conCount = $testcase.ConnectionCount
    $expectedResult = "ConnectionsSucceded:$conCount, ConnectionsFailed:0"
    if($testcase.ExpectedResult -and ($testcase.ExpectedResult -ne "")) {
        $expectedResult = $testcase.ExpectedResult
    }
    $tcaseName = NewTestCaseName -testcaseName $testcase.Name -serviceIP $clusterIP -servicePort $servicePort
    LogResult -logPath $appInfo.LogPath -useIPV6 $useIPV6  -testcaseName $tcaseName -index $index -expectedResult $expectedResult -actualResult $result[$result.Count-1]
}

function RunActions {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [string]$clientName,
        [Parameter (Mandatory = $true)] [string]$ipAddress,
        [Parameter (Mandatory = $true)] [string]$servicePort,
        [Parameter (Mandatory = $true)] [int]$index,
        [Parameter (Mandatory = $true)] [bool]$useIPV6,
        [Parameter (Mandatory = $false)] [bool]$extClient = $false
    )


    $namespace = $appInfo.Namespace
    $connCount = $testcase.ConnectionCount
    $requestsPerConnection = $testcase.RequestsPerConnection
    $timeBtwEachRequestInMs = $testcase.TimeBtwEachRequestInMs

    $failProbeCount = 0

    $actionCount = ($testcase.Actions).Count

    for($i = 1; $i -le $actionCount; $i++) {

        foreach($action in $testcase.Actions) {

            if($action.Seq -ne $i) {
                continue
            }
            
            if($action.$ActionStartTcpClient) { 
                Log "Start TCP Connection to $ipAddress : $servicePort in background"
    
                if($extClient) {
                    $Job = Start-Job -ScriptBlock { 
                        bin\client.exe -i $args[0] -p $args[1] -c $args[2] -r $args[3] -d $args[4]
                    } -ArgumentList $ipAddress, $servicePort, $connCount, $requestsPerConnection, $timeBtwEachRequestInMs
                } else {
                    $Job = Start-Job -ScriptBlock {
                        kubectl exec $args[0] -n $args[1] -- client -i $args[2] -p $args[3] -c $args[4] -r $args[5] -d $args[6]
                    } -ArgumentList $clientName, $namespace, $ipAddress, $servicePort, $connCount, $requestsPerConnection, $timeBtwEachRequestInMs
                } 
            }
    
            if($action.$ActionScaleTo) {
                ScalePodsInBackground -namespace $appInfo.Namespace -deploymentName $appInfo.ServerDeploymentName -podCount $action.$ActionScaleTo 
            }
    
            if($action.$ActionFailReadinessProbe) {
                FailReadinessProbeForAllServerPods -namespace $appInfo.Namespace -clientDeploymentName $appInfo.ClientDeploymentName -serverDeploymentName $appInfo.ServerDeploymentName -useIPV6 $useIPV6
                $failProbeCount++
            }
    
            if($action.$ActionPassReadinessProbe) {
                PassReadinessProbeForAllServerPods -namespace $appInfo.Namespace -clientDeploymentName $appInfo.ClientDeploymentName -serverDeploymentName $appInfo.ServerDeploymentName -useIPV6 $useIPV6
                $failProbeCount--
            }

            if($action.$ActionSleep) {
                $sleepTime = $action.$ActionSleep
                Log "Sleep Action Invoked. Sleeping for $sleepTime seconds."
                Start-Sleep -Seconds $action.$ActionSleep 
            }

            break
        }
    }

    if($failProbeCount -gt 0) {
        PassReadinessProbeForAllServerPods -namespace $appInfo.Namespace -clientDeploymentName $appInfo.ClientDeploymentName -serverDeploymentName $appInfo.ServerDeploymentName -useIPV6 $useIPV6
    }

    WaitForPodsToBeReady -namespace $appInfo.Namespace

    Wait-Job $Job
    $result = Receive-Job $Job
    Remove-Job $job

    $resultStr = $result | findstr "ConnectionsSucceded"
    return $resultStr 
}