$Global:nodePoolName = "npwin"


$Global:ActionsSupportedTypes = @{
    "PodToClusterIP" = $true
    "PodToIngressIP" = $true
    "ExternalToIngressIP" = $true
}


function Log {
    param (
        [Parameter (Mandatory = $true)] [String]$logMsg
    )
    Write-Host " "
    Write-Host "#========= $logMsg "
}

function LogResult {
    param (
        [Parameter (Mandatory = $true)] [String]$logPath,
        [Parameter (Mandatory = $true)] [String]$testcaseName,
        [Parameter (Mandatory = $true)] [String]$index,
        [Parameter (Mandatory = $true)] [System.Boolean]$useIPV6,
        [Parameter (Mandatory = $true)] [String]$expectedResult,
        [Parameter (Mandatory = $true)] [String]$actualResult
    )
    $ipVersion = "IPV4"
    if($useIPV6) {
        $ipVersion = "IPV6"
    }
    if($actualResult.Contains($expectedResult)) {
        $result = "[PASSED] Testcase $index : [$ipVersion][$testcaseName] - Result: $actualResult"
    } else {
        $result = "[FAILED] Testcase $index : [$ipVersion][$testcaseName] - Result: $actualResult"
    }
    Log $result
    Add-content $logPath -value $result
}

function LogPingResult {
    param (
        [Parameter (Mandatory = $true)] [String]$logPath,
        [Parameter (Mandatory = $true)] [String]$testcaseName,
        [Parameter (Mandatory = $true)] [String]$index,
        [Parameter (Mandatory = $true)] [System.Boolean]$useIPV6,
        [Parameter (Mandatory = $true)] [String]$result
    )
    $ipVersion = "IPV4"
    if($useIPV6) {
        $ipVersion = "IPV6"
    }
    if($result.Contains("True")) {
        $result = "[PASSED] Testcase $index : [$ipVersion][$testcaseName] - Result: $result"
    } else {
        $result = "[FAILED] Testcase $index : [$ipVersion][$testcaseName] - Result: $result"
    }
    Log $result
    Add-content $logPath -value $result
}

function GetPodNameFromNode {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$nodeName,
        [Parameter (Mandatory = $true)] [String]$deploymentName,
        [Parameter (Mandatory = $false)] [System.Boolean]$isRemoteNode = $false
    )
    $items = (kubectl get pods -n $namespace -o json | ConvertFrom-Json).Items | Select-Object metadata, spec
    foreach($item in $items) {
        if($isRemoteNode) {
            if($item.spec.nodeName -ne $nodeName) {
                $metadatas = $item.metadata
                foreach($metadata in $metadatas) { 
                    if(($metadata.labels).app -eq $deploymentName ) { 
                        return $metadata.name 
                    }
                    if(($metadata.labels).Name -eq $deploymentName ) { 
                        return $metadata.name 
                    } 
                }
            }
        } else {
            if($item.spec.nodeName -eq $nodeName) {
                $metadatas = $item.metadata
                foreach($metadata in $metadatas) { 
                    if(($metadata.labels).app -eq $deploymentName ) { 
                        return $metadata.name 
                    }
                    if(($metadata.labels).Name -eq $deploymentName ) { 
                        return $metadata.name 
                    } 
                }
            }
        }
    }
    return ""
}

function GetAllPodNames {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$deploymentName
    )
    $podNames = @()
    $metadatas = ((kubectl get pods -n $namespace -o json | ConvertFrom-Json).Items).metadata
    foreach($metadata in $metadatas) { 
        if(($metadata.labels).app -eq $deploymentName ) { 
            $podNames += $metadata.name 
        } elseif(($metadata.labels).Name -eq $deploymentName ) { 
            $podNames += $metadata.name 
        } 
    }
    return $podNames
}

function GetAllWindowsNodeNames {
    param (
        [Parameter (Mandatory = $true)] [String]$nodePoolName
    )
    $winNodeNames = @()
    $allNodeNames = ((kubectl get nodes -o json | ConvertFrom-Json).Items).metadata.name
    foreach($name in $allNodeNames) {
        if($name.Contains($nodePoolName)) {
            $winNodeNames += $name
        }
    }
    return $winNodeNames
}

function GetPodName {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$deploymentName
    )
    $metadatas = ((kubectl get pods -n $namespace -o json | ConvertFrom-Json).Items).metadata
    foreach($metadata in $metadatas) { 
        if(($metadata.labels).app -eq $deploymentName ) { 
            return $metadata.name 
        }
        if(($metadata.labels).Name -eq $deploymentName ) { 
            return $metadata.name 
        } 
    }
    return ""
}

function GetPodNameFromIP {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$podIP
    )
    $items = ((kubectl get pods -n $namespace -o json | ConvertFrom-Json).Items)
    foreach($item in $items) {
        if ($item.status.podIP -eq $podIP) {
            return $item.metadata.name
        }
    }
    return ""
}

function GetClientName {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$deploymentName
    )
    return GetPodName -namespace $namespace -deploymentName $deploymentName
}

function GetNodeNameFromPodName {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$podName
    )
    return (kubectl get pods $podName -n $namespace -o json | ConvertFrom-Json).spec.nodeName
}

function GetNodeIPFromPodName {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$podName
    )
    return (kubectl get pods $podName -n $namespace -o json | ConvertFrom-Json).status.hostIP
}

function GetLocalNodeIP {
    param (
        [Parameter (Mandatory = $true)] [String]$nodeName,
        [Parameter (Mandatory = $false)] [bool]$useIPV6 = $false
    )
    $statuses = (kubectl get nodes $nodeName -o json | ConvertFrom-Json).status
    foreach($status in $statuses) {
        foreach($address in $status.addresses) {
            if($useIPV6) {
                if($address.address.Contains(":")) {
                    return $address.address
                }
            } elseif ($address.address.Split(".").Count -eq 4) {
                return $address.address
            }
        }
    }
    return ""
}

function GetRemoteNodeIP {
    param (
        [Parameter (Mandatory = $true)] [String]$nodeName,
        [Parameter (Mandatory = $false)] [bool]$useIPV6 = $false
    )
    $statuses = ((kubectl get nodes -o json | ConvertFrom-Json).items).status
    foreach($status in $statuses) {
        $rightHost = $false
        foreach($address in $status.addresses) {
            if($address.address.Contains($nodePoolName) -and ($address.address -ne $nodeName)) {
                $rightHost = $true
            }
        }
        if($rightHost) {
            foreach($address in $status.addresses) {
                if($useIPV6) {
                    if($address.address.Contains(":")) {
                        return $address.address
                    }
                } elseif ($address.address.Split(".").Count -eq 4) {
                    return $address.address
                }
            }
        }
    }
    return ""
}

function EnsurePodsAreDistributed {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$tcaseName,
        [Parameter (Mandatory = $true)] [Int32]$index,
        [Parameter (Mandatory = $true)] [String]$serverDeploymentName,
        [Parameter (Mandatory = $true)] [Int32]$serverPodCount,
        [Parameter (Mandatory = $false)] [bool]$useIPV6 = $false
    )

    $winNodeIPs = GetNodeIPs -useIPV6 $useIPV6
    $attempts = 10

    for ($i = 1; $i -le $attempts; $i++) {

        Log "Scaling the server pods to $serverPodCount"
        kubectl scale --replicas=$serverPodCount deployment/$serverDeploymentName -n $namespace
        
        if(!(WaitForPodsToBeReady -namespace $namespace)) {
            Log "Containers didn't come up."
            $result = "Testcase $index : $tcaseName - FAILED . Remarks : Pods didn't come up."
            Log $result
            Add-content $logPath -value $result
            return $false
        }

        # Storing nodeips to a hashtable for easy lookup
        $winNodeIPsHashTable = @{ }
        foreach($ip in $winNodeIPs) {
            $winNodeIPsHashTable[$ip] = $true
        }

        $serverPodIPs = GetAllServerPodIPs -namespace $namespace -serverDeploymentName $serverDeploymentName -useIPV6 $useIPV6
        # Ensuring pods are equally distributed
        foreach($podIP in $serverPodIPs) {
            $nodeIP = GetNodeIPFromPodName -namespace $namespace -podName (GetPodNameFromIP -namespace $namespace -podIP $podIP)
            if($winNodeIPsHashTable[$nodeIP]) {
                $winNodeIPsHashTable.Remove($nodeIP)
            }
        }
        if($winNodeIPsHashTable.Count -eq 0) {
            return $true
        }
        $nodeKeys = $winNodeIPsHashTable.Keys
        Log "Pods are not distributed. Attempt : $i. These nodes still don't have pods. $nodeKeys"
        Log "Scaling the pods to 0."
        kubectl scale --replicas=0 deployment/$serverDeploymentName -n $namespace
        Start-Sleep -Seconds 10
    }
    $result = "Testcase $index : $tcaseName - FAILED . Remarks : Pod distribution failed."
    Log $result
    Add-content $logPath -value $result
}

function GetNodeIPs {
    param (
        [Parameter (Mandatory = $false)] [bool]$useIPV6 = $false
    )
    $nodeIPs = @()
    $statuses = ((kubectl get nodes -o json | ConvertFrom-Json).items).status
    foreach($status in $statuses) {
        $rightHost = $false
        foreach($address in $status.addresses) {
            if($address.address.Contains($nodePoolName)) {
                $rightHost = $true
            }
        }

        if($rightHost) {
            foreach($address in $status.addresses) {
                if($useIPV6) {
                    if($address.address.Contains(":")) {
                        $nodeIPs += $address.address
                    }
                } elseif ($address.address.Split(".").Count -eq 4) {
                    $nodeIPs += $address.address
                }
            }
        }

    }
    return $nodeIPs
}

function GetLinuxNodeIPs {
    param (
        [Parameter (Mandatory = $false)] [bool]$useIPV6 = $false
    )
    $nodeIPs = @()
    $statuses = ((kubectl get nodes -o json | ConvertFrom-Json).items).status
    foreach($status in $statuses) {
        $windowsHost = $false
        foreach($address in $status.addresses) {
            if($address.address.Contains($nodePoolName)) {
                $windowsHost = $true
            }
        }

        if(!$windowsHost) {
            foreach($address in $status.addresses) {
                if($useIPV6) {
                    if($address.address.Contains(":")) {
                        $nodeIPs += $address.address
                    }
                } elseif ($address.address.Split(".").Count -eq 4) {
                    $nodeIPs += $address.address
                }
            }
        }

    }
    return $nodeIPs
}

function GetLocalServerPodIP {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$clientDeploymentName,
        [Parameter (Mandatory = $true)] [String]$serverDeploymentName,
        [Parameter (Mandatory = $false)] [bool]$useIPV6 = $false
    )
    $items = ((kubectl get pods -n $namespace -o json | ConvertFrom-Json).Items)
    foreach($item in $items) {
        if((($item.metadata).labels).app -eq $clientDeploymentName) { 
            $nodeName = ($item.spec).nodeName
            break
        } 
    }
    foreach($item in $items) {
        if(($item.spec).nodeName -eq $nodeName -and ((($item.metadata).labels).app -eq $serverDeploymentName)) {
            if($useIPV6) {
                return $item.status.podIPs[1].ip
            }
            return ($item.status).podIP
        }
    }
    return ""
}

function GetRemoteServerPodIP {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$clientDeploymentName,
        [Parameter (Mandatory = $true)] [String]$serverDeploymentName,
        [Parameter (Mandatory = $false)] [bool]$useIPV6 = $false
    )
    $items = ((kubectl get pods -n $namespace -o json | ConvertFrom-Json).Items)
    foreach($item in $items) {
        if((($item.metadata).labels).app -eq $clientDeploymentName) { 
            $nodeName = ($item.spec).nodeName
            break
        } 
    }
    foreach($item in $items) {
        if(($item.spec).nodeName -ne $nodeName -and ((($item.metadata).labels).app -eq $serverDeploymentName)) {
            if($useIPV6) {
                return $item.status.podIPs[1].ip
            }
            return ($item.status).podIP
        }
    }
    return ""
}

function GetAllServerPodIPs {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$serverDeploymentName,
        [Parameter (Mandatory = $false)] [bool]$useIPV6 = $false
    )
    $podIPs = @()
    $items = ((kubectl get pods -n $namespace -o json | ConvertFrom-Json).Items)
    foreach($item in $items) {
        if($item.metadata.labels.app -eq $serverDeploymentName) {
            if($useIPV6) {
                $podIPs += $item.status.podIPs[1].ip
            } else {
                $podIPs += ($item.status).podIP
            } 
        }
    }
    return $podIPs
}

function GetClusterIP {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$serviceName
    )
    $items = (kubectl get services -n $namespace -o json | ConvertFrom-Json).Items
    foreach($item in $items) { 
        if(($item.metadata).name -eq $serviceName) { 
            return ($item.spec).clusterIP 
        } 
    }
    return ""
}

function GetNodePort {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$serviceName,
        [Parameter (Mandatory = $false)] [String]$protocolName = "tcp"
    )
    $items = (kubectl get services -n $namespace -o json | ConvertFrom-Json).Items
    foreach($item in $items) { 
        if(($item.metadata).name -eq $serviceName) {
            $ports = ($item.spec).ports
            foreach($port in $ports) {
                if($port.name -eq $protocolName) {
                    return $port.nodePort
                }
            }
        } 
    }
    return ""
}

function GetIngressIP {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$serviceName
    )
    $items = (kubectl get services -n $namespace -o json | ConvertFrom-Json).Items
    foreach($item in $items) { 
        if(($item.metadata).name -eq $serviceName) { 
            return $item.status.loadBalancer.ingress.ip
        } 
    }
    return ""
}

function MakeEnoughPodsForPodToPodTesting {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$appInfo
    )
    $nodeCount = ((kubectl get nodes -o json | ConvertFrom-Json).items).Count
    $podCount = ((kubectl get pods -n $appInfo.Namespace -o json | ConvertFrom-Json).items).Count
    $expPodCount = $nodeCount + 3
    if($podCount -ge $expPodCount) {
        return $true
    }

    $depName = $appInfo.ServerDeploymentName
    Log "Scaling the server pods to $serverPodCount"
    kubectl scale --replicas=$expPodCount deployment/$depName -n $appInfo.Namespace
    if(!(WaitForPodsToBeReady -namespace $appInfo.Namespace)) {
        Log "Containers didn't come up."
        return $false
    }
    return $true
}

function ScalePodsInBackground {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$deploymentName,
        [Parameter (Mandatory = $true)] [Int32]$podCount
    )
    Log "Scaling the server pods to $podCount"
    kubectl scale --replicas=$podCount deployment/$deploymentName -n $namespace
    return $true
}

function ScalePods {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [System.Object]$appInfo,
        [Parameter (Mandatory = $true)] [Int32]$index
    )
    if(!($testcase.ServerPodCount)) {
        return $true
    }
    $tcaseName = $testcase.Name
    $depName = $appInfo.ServerDeploymentName
    $serverPodCount = $testcase.ServerPodCount
    Log "Scaling the server pods to $serverPodCount"
    kubectl scale --replicas=$serverPodCount deployment/$depName -n $appInfo.Namespace
    if(!(WaitForPodsToBeReady -namespace $appInfo.Namespace)) {
        Log "Containers didn't come up."
        $result = "Testcase $index : $tcaseName - FAILED . Remarks : Pods didn't come up."
        Log $result
        Add-content $logPath -value $result
        return $false
    }
    return $true
}

function WaitForPodsToBeReady {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace
    )
    $count = 200
    while ($count--) {
        $allReady = $true
        $podJson = kubectl get pods -n $namespace -o json | ConvertFrom-Json
        $readyStatus = ((($podJson.items).status).containerStatuses).ready
        foreach($isReady in $readyStatus) {
            if($isReady -eq $false) {
                $allReady = $false
                break
            }
        }
        if($allReady) {
            return $true
        }
        Log "Waiting for Pods to be Ready"
        Start-Sleep -Seconds 5
    }
    return $false
}

function WaitForPodsToBeNonReady {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$deployment
    )
    $count = 200
    while ($count--) {
        $status = (kubectl get deployment $deployment -n $namespace -o json | ConvertFrom-Json ).status
        if($status.replicas -eq $status.unavailableReplicas) {
            return $true
        }
        Log "Waiting for Pods to be Non Ready"
        Start-Sleep -Seconds 5
    }
    return $false
}

function WaitForServicesToBeReady {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace
    )
    return $true
    $count = 200
    while ($count--) {
        $pendingServices = kubectl get services -n $namespace | findstr "pending"
        if($pendingServices.Count -eq 0) {
            return $true
        }
        Log "Waiting for Services to be Ready. Pending Services : $pendingServices"
        Start-Sleep -Seconds 5
    }
    return $false
}

function FailReadinessProbeForAllServerPods {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$clientDeploymentName,
        [Parameter (Mandatory = $true)] [String]$serverDeploymentName,
        [Parameter (Mandatory = $false)] [bool]$useIPV6 = $false
    )

    $serverPodIPs = GetAllServerPodIPs -namespace $namespace -serverDeploymentName $serverDeploymentName -useIPV6 $useIPV6
    $clientName = GetClientName -namespace $namespace -deploymentName $clientDeploymentName
    Log "Failing readiness probe for all server pods started. PodIPs : $serverPodIPs"

    foreach($podIP in $serverPodIPs) {
        $apiReq = "curl $podIP`:8090/failreadinessprobe -UseBasicParsing"
        if($useIPV6) {
            $apiReq = "curl [$podIP]:8090/failreadinessprobe -UseBasicParsing"
        }
        $result = kubectl exec $clientName -n $namespace -- powershell -command $apiReq
        Log "FailReadiness Probe for $podIP status : $result"
    }

    WaitForPodsToBeNonReady -namespace $namespace -deployment $serverDeploymentName

    Log "Failing readiness probe for all server pods completed."
}

function IpInNodeIPList {
    param (
        [Parameter (Mandatory = $true)] [String]$ip,
        [Parameter (Mandatory = $true)] [String[]]$linuxNodeIPs,
        [Parameter (Mandatory = $true)] [String[]]$winNodeIPs
    )
    foreach($nodeIP in $linuxNodeIPs) {
        if($nodeIP -eq $ip) {
            return $true
        }
    }
    foreach($nodeIP in $winNodeIPs) {
        if($nodeIP -eq $ip) {
            return $true
        }
    }
    return $false
}

function ResetMetrics {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$clientName,
        [Parameter (Mandatory = $true)] [String[]]$serverPodIPs
    )
    foreach($podIP in $serverPodIPs) {
        Log "Resetmetrics for pod ip : $podIP"
        $resetMetricsApiReq = "curl $podIP`:8090/resetmetrics -UseBasicParsing"
        if($useIPV6) {
            $resetMetricsApiReq = "curl [$podIP]:8090/resetmetrics -UseBasicParsing"
        }
        $result = kubectl exec $clientName -n $namespace -- powershell -command $resetMetricsApiReq
        Log "Resetting metrics for $podIP status : $result"
    }
}

function GetTcpConnectedIPs {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$clientName,
        [Parameter (Mandatory = $true)] [String[]]$serverPodIPs
    )
    $ipAddressList = @()
    foreach($podIP in $serverPodIPs) {
        $readMetricsApiReq = "((curl http://$podIP`:8090/metrics -UseBasicParsing | select Content).Content | ConvertFrom-Json).tcp.ip_addresses"
        if($useIPV6) {
            $readMetricsApiReq = "((curl http://[$podIP]:8090/metrics -UseBasicParsing | select Content).Content | ConvertFrom-Json).tcp.ip_addresses"
        }
        $result = (kubectl exec $clientName -n $namespace -- powershell -command $readMetricsApiReq)
        Log "Reading metrics for $podIP status : $result"
        if (($null -ne $result) -and ($result.Count -gt 0)) {
            return $result, $podIP
        }
    }
    return $ipAddressList, ""
}

function PassReadinessProbeForAllServerPods {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$clientDeploymentName,
        [Parameter (Mandatory = $true)] [String]$serverDeploymentName,
        [Parameter (Mandatory = $false)] [bool]$useIPV6 = $false
    )

    $serverPodIPs = GetAllServerPodIPs -namespace $namespace -serverDeploymentName $serverDeploymentName -useIPV6 $useIPV6
    $clientName = GetClientName -namespace $namespace -deploymentName $clientDeploymentName
    Log "Passing readiness probe for all server pods started. PodIPS : $serverPodIPs"

    foreach($podIP in $serverPodIPs) {
        $apiReq = "curl $podIP`:8090/passreadinessprobe -UseBasicParsing"
        if($useIPV6) {
            $apiReq = "curl [$podIP]:8090/passreadinessprobe -UseBasicParsing"
        }
        $result = kubectl exec $clientName -n $namespace -- powershell -command $apiReq
        Log "PassReadiness Probe for $podIP status : $result"
    }

    WaitForPodsToBeReady -namespace $namespace

    Log "Passing readiness probe for all server pods completed."
}

function IsActionUnSupported {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$testcase,
        [Parameter (Mandatory = $true)] [string]$logPath
    )
    if($Global:ActionsSupportedTypes[$testcase.Type]) {
        return $false
    }
    if(($testcase.Actions) -and ($testcase.Actions).Count -gt 0) {
        $tcaseType = $testcase.Type
        $tcaseName = $testcase.Name
        $result = "[SKIPPED][$tcaseName] Reason : Actions not supported for $tcaseType"
        Log $result
        Add-content $logPath -value $result
        return $true
    }
    return $false
}

function NewTestCaseName {
    param (
        [Parameter (Mandatory = $true)] [String]$testcaseName,
        [Parameter (Mandatory = $true)] [String]$serviceIP,
        [Parameter (Mandatory = $false)] [String]$servicePort = ""
    )
    if($servicePort -eq "") {
        return "$testcaseName [$serviceIP]"
    }
    return "$testcaseName [$serviceIP : $servicePort]"
}

function CopyTcpClientToNodes {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$deploymentName
    )
    
    $allPodNames = GetAllPodNames -namespace $namespace -deploymentName $deploymentName
    foreach($podName in $allPodNames) {
        $clientExists = kubectl exec $podName -n $namespace -- powershell -command Test-Path C:\k\client.exe
        if($clientExists -eq $true) {
            Log "Client exists in : $podName"
            continue
        }
        Log "Copying binary zip to : $podName"
        kubectl cp .\bin\bin.zip $podName`:bin.zip -n $namespace
        Log "Extracting binary zip inside : $podName"
        kubectl exec $podName -n $namespace -- powershell -command Expand-Archive -Path bin.zip -DestinationPath .
        Log "Copying client.exe to C:\k path in : $podName"
        kubectl exec $podName -n $namespace -- powershell -command cp .\bin\client.exe C:\k\.
    }
}

function Abc {
    $clientName = "tcp-client-5fd56f8dc7-l6zdd"
    $namespace = "demo"
    $ipAddress = "fd39:a5ef:4d7f:e743::1f34"
    $servicePort = "4444"
    $connCount = 4
    $requestsPerConnection = 10
    $timeBtwEachRequestInMs = 1000

    $Job = Start-Job -ScriptBlock { 
        # $result = kubectl exec $args[0] -n $args[1] -- client -i $args[2] -p $args[3] -c $args[4] -r $args[5] -d $args[6]
        $clientName = $args[0]
        $namespace = $args[1]
        $ipAddress = $args[2]
        $servicePort = $args[3]
        $connCount = $args[4]
        $requestsPerConnection = $args[5]
        $timeBtwEachRequestInMs = $args[6]
        kubectl exec $clientName -n $namespace -- powershell -command "client -i $ipAddress -p $servicePort -c $connCount -r $requestsPerConnection -d $timeBtwEachRequestInMs | tee mylog.txt"
        return kubectl exec $clientName -n $namespace -- powershell -command "Get-Content .\mylog.txt"
    } -ArgumentList $clientName, $namespace, $ipAddress, $servicePort, $connCount, $requestsPerConnection, $timeBtwEachRequestInMs
    
    # Start-Sleep -Seconds 120

    Wait-Job $Job
    $result = Receive-Job $Job
    Remove-Job $job

    Log "AAAAAAAAAAAAA"
    $resultStr = $result | findstr "ConnectionsSucceded"
    Log "BBBB "
    $resultStr = $result | findstr "ConnectionsSucceded"
    return $resultStr
}