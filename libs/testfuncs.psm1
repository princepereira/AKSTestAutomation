Import-Module -Force .\libs\utils.psm1

function TestPodToClusterIP {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $serverPodCount = $testcase.ServerPodCount
    $tcaseName = $testcase.Name
    $depName = $appInfo.ServerDeploymentName
    Log "Scaling the server pods to $serverPodCount"
    kubectl scale --replicas=$serverPodCount deployment/$depName -n $appInfo.Namespace
    if(!(WaitForPodsToBeReady -namespace $appInfo.Namespace)) {
        Log "Containers didn't come up."
        $result = "Testcase $index : $tcaseName - FAILED . Remarks : Pods didn't come up."
        Log $result
        Add-content $logPath -value $result
        return $false
    }
    Log "Pods"
    kubectl get pods -o wide -n $appInfo.Namespace
    Log "Start TCP Connection"

    $serviceName = $appInfo.ETPClusterServiceName
    $servicePort = $appInfo.ETPClusterServicePort
    if($testcase.ServiceType -eq "ETPLocal") {
        $serviceName = $appInfo.ETPLocalServiceName
        $servicePort = $appInfo.ETPLocalServicePort
    }

    if($testcase.UseIPV6) {
        $serviceName = $appInfo.ETPClusterServiceNameIPV6
        $servicePort = $appInfo.ETPClusterServicePortIPV6
        if($testcase.ServiceType -eq "ETPLocal") {
            $serviceName = $appInfo.ETPLocalServiceNameIPV6
            $servicePort = $appInfo.ETPLocalServicePortIPV6
        }
    }
    
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $clusterIP = GetClusterIP -namespace $appInfo.Namespace -serviceName $serviceName
    $result = kubectl exec $clientName -n $appInfo.Namespace -- client -i $clusterIP -p $servicePort -c $testcase.ConnectionCount -r $testcase.RequestsPerConnection -d $testcase.TimeBtwEachRequestInMs
    $conCount = $testcase.ConnectionCount
    $expectedResult = "ConnectionsSucceded:$conCount, ConnectionsFailed:0"
    LogResult -logPath $appInfo.LogPath -testcaseName $testcase.Name -index $index -expectedResult $expectedResult -actualResult $result[$result.Count-1]
}

function TestPodToNodePort {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $serverPodCount = $testcase.ServerPodCount
    $tcaseName = $testcase.Name
    $depName = $appInfo.ServerDeploymentName
    Log "Scaling the server pods to $serverPodCount"
    kubectl scale --replicas=$serverPodCount deployment/$depName -n $appInfo.Namespace
    if(!(WaitForPodsToBeReady -namespace $appInfo.Namespace)) {
        Log "Containers didn't come up."
        $result = "Testcase $index : $tcaseName - FAILED . Remarks : Pods didn't come up."
        Log $result
        Add-content $logPath -value $result
        return $false
    }
    Log "Pods"
    kubectl get pods -o wide -n $appInfo.Namespace

    $serviceName = $appInfo.ETPClusterServiceName
    if($testcase.ServiceType -eq "ETPLocal") {
        $serviceName = $appInfo.ETPLocalServiceName
    }

    $useIPV6 = $false
    if($testcase.UseIPV6) {
        $useIPV6 = $true
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
        LogResult -logPath $appInfo.LogPath -testcaseName $testcase.Name -index $newIndex -expectedResult $expectedResult -actualResult $result[$result.Count-1]
    }
}

function TestPodToIngressIP {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $serverPodCount = $testcase.ServerPodCount
    $tcaseName = $testcase.Name
    $depName = $appInfo.ServerDeploymentName
    Log "Scaling the server pods to $serverPodCount"
    kubectl scale --replicas=$serverPodCount deployment/$depName -n $appInfo.Namespace
    if(!(WaitForPodsToBeReady -namespace $appInfo.Namespace)) {
        Log "Containers didn't come up."
        $result = "Testcase $index : $tcaseName - FAILED . Remarks : Pods didn't come up."
        Log $result
        Add-content $logPath -value $result
        return $false
    }
    Log "Pods"
    kubectl get pods -o wide -n $appInfo.Namespace
    Log "Start TCP Connection"

    $serviceName = $appInfo.ETPClusterServiceName
    $servicePort = $appInfo.ETPClusterServicePort
    if($testcase.ServiceType -eq "ETPLocal") {
        $serviceName = $appInfo.ETPLocalServiceName
        $servicePort = $appInfo.ETPLocalServicePort
    }

    if($testcase.UseIPV6) {
        $serviceName = $appInfo.ETPClusterServiceNameIPV6
        $servicePort = $appInfo.ETPClusterServicePortIPV6
        if($testcase.ServiceType -eq "ETPLocal") {
            $serviceName = $appInfo.ETPLocalServiceNameIPV6
            $servicePort = $appInfo.ETPLocalServicePortIPV6
        }
    }

    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $ingressIP = GetIngressIP -namespace $appInfo.Namespace -serviceName $serviceName
    $result = kubectl exec $clientName -n $appInfo.Namespace -- client -i $ingressIP -p $servicePort -c $testcase.ConnectionCount -r $testcase.RequestsPerConnection -d $testcase.TimeBtwEachRequestInMs
    $conCount = $testcase.ConnectionCount
    $expectedResult = "ConnectionsSucceded:$conCount, ConnectionsFailed:0"
    LogResult -logPath $appInfo.LogPath -testcaseName $testcase.Name -index $index -expectedResult $expectedResult -actualResult $result[$result.Count-1]
}

function TestExternalToIngressIP {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $serverPodCount = $testcase.ServerPodCount
    $tcaseName = $testcase.Name
    $depName = $appInfo.ServerDeploymentName
    Log "Scaling the server pods to $serverPodCount"
    kubectl scale --replicas=$serverPodCount deployment/$depName -n $appInfo.Namespace
    if(!(WaitForPodsToBeReady -namespace $appInfo.Namespace)) {
        Log "Containers didn't come up."
        $result = "Testcase $index : $tcaseName - FAILED . Remarks : Pods didn't come up."
        Log $result
        Add-content $logPath -value $result
        return $false
    }
    Log "Pods"
    kubectl get pods -o wide -n $appInfo.Namespace
    Log "Start TCP Connection"

    $serviceName = $appInfo.ETPClusterServiceName
    $servicePort = $appInfo.ETPClusterServicePort
    if($testcase.ServiceType -eq "ETPLocal") {
        $serviceName = $appInfo.ETPLocalServiceName
        $servicePort = $appInfo.ETPLocalServicePort
    }

    if($testcase.UseIPV6) {
        $serviceName = $appInfo.ETPClusterServiceNameIPV6
        $servicePort = $appInfo.ETPClusterServicePortIPV6
        if($testcase.ServiceType -eq "ETPLocal") {
            $serviceName = $appInfo.ETPLocalServiceNameIPV6
            $servicePort = $appInfo.ETPLocalServicePortIPV6
        }
    }

    $ingressIP = GetIngressIP -namespace $appInfo.Namespace -serviceName $serviceName
    $result = bin\client.exe -i $ingressIP -p $servicePort -c $testcase.ConnectionCount -r $testcase.RequestsPerConnection -d $testcase.TimeBtwEachRequestInMs
    $conCount = $testcase.ConnectionCount
    $expectedResult = "ConnectionsSucceded:$conCount, ConnectionsFailed:0"
    LogResult -logPath $appInfo.LogPath -testcaseName $testcase.Name -index $index -expectedResult $expectedResult -actualResult $result[$result.Count-1]
}

function TestPodToLocalPod {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    MakeEnoughPodsForPodToPodTesting -appInfo $appInfo
    $useIPV6 = $false
    if($testcase.UseIPV6) {
        $useIPV6 = $true
    }
    $localPodIP = GetLocalServerPodIP -namespace $appInfo.Namespace -clientDeploymentName $appInfo.ClientDeploymentName -serverDeploymentName $appInfo.ServerDeploymentName -useIPV6 $useIPV6
    $internalPort = $appInfo.InternalPort
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    Log "Start TCP Connection"
    $result = kubectl exec $clientName -n $appInfo.Namespace -- client -i $localPodIP -p $internalPort -c $testcase.ConnectionCount -r $testcase.RequestsPerConnection -d $testcase.TimeBtwEachRequestInMs
    $conCount = $testcase.ConnectionCount
    $expectedResult = "ConnectionsSucceded:$conCount, ConnectionsFailed:0"
    LogResult -logPath $appInfo.LogPath -testcaseName $testcase.Name -index $index -expectedResult $expectedResult -actualResult $result[$result.Count-1]
}

function TestPodToLocalNode {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $nodeName = GetNodeNameFromPodName -namespace $appInfo.Namespace -podName $clientName
    $useIPV6 = $false
    if($testcase.UseIPV6) {
        $useIPV6 = $true
    }
    $localNodeIP = GetLocalNodeIP -nodeName $nodeName -useIPV6 $useIPV6
    Log "Start Test-NetConnection"
    $result = kubectl exec $clientName -n $appInfo.Namespace -- powershell -ExecutionPolicy Unrestricted -command Test-NetConnection -RemoteAddress $localNodeIP | findstr "Succeeded"
    $tcaseName = $testcase.Name
    $tcaseName = "$tcaseName [LocalNodeIP:$localNodeIP]"
    LogPingResult -logPath $appInfo.LogPath -testcaseName $tcaseName -index $index -result $result
}

function TestPodToRemoteNode {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $nodeName = GetNodeNameFromPodName -namespace $appInfo.Namespace -podName $clientName
    $useIPV6 = $false
    if($testcase.UseIPV6) {
        $useIPV6 = $true
    }
    $remoteNodeIP = GetRemoteNodeIP -nodeName $nodeName -useIPV6 $useIPV6
    Log "Start Test-NetConnection"
    $result = kubectl exec $clientName -n $appInfo.Namespace -- powershell -ExecutionPolicy Unrestricted -command Test-NetConnection -RemoteAddress $remoteNodeIP | findstr "Succeeded"
    $tcaseName = $testcase.Name
    $tcaseName = "$tcaseName [RemoteNodeIP:$remoteNodeIP]"
    LogPingResult -logPath $appInfo.LogPath -testcaseName $tcaseName -index $index -result $result
}

function TestPodToInternet {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    Log "Start Test-NetConnection"
    $result = kubectl exec $clientName -n $appInfo.Namespace -- powershell -ExecutionPolicy Unrestricted -command Test-NetConnection -p 80 | findstr "Succeeded"
    $tcaseName = $testcase.Name
    LogPingResult -logPath $appInfo.LogPath -testcaseName $tcaseName -index $index -result $result
}

function TestPodToRemotePod {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    MakeEnoughPodsForPodToPodTesting -appInfo $appInfo
    $clientName = GetClientName -namespace $appInfo.Namespace -deploymentName $appInfo.ClientDeploymentName
    $useIPV6 = $false
    if($testcase.UseIPV6) {
        $useIPV6 = $true
    }
    $localPodIP = GetRemoteServerPodIP -namespace $appInfo.Namespace -clientDeploymentName $appInfo.ClientDeploymentName -serverDeploymentName $appInfo.ServerDeploymentName -useIPV6 $useIPV6
    $internalPort = $appInfo.InternalPort
    Log "Start TCP Connection"
    $result = kubectl exec $clientName -n $appInfo.Namespace -- client -i $localPodIP -p $internalPort -c $testcase.ConnectionCount -r $testcase.RequestsPerConnection -d $testcase.TimeBtwEachRequestInMs
    $conCount = $testcase.ConnectionCount
    $expectedResult = "ConnectionsSucceded:$conCount, ConnectionsFailed:0"
    LogResult -logPath $appInfo.LogPath -testcaseName $testcase.Name -index $index -expectedResult $expectedResult -actualResult $result[$result.Count-1]
}
