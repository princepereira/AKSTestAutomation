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
        [Parameter (Mandatory = $true)] [String]$serviceName
    )
    $items = (kubectl get services -n $namespace -o json | ConvertFrom-Json).Items
    foreach($item in $items) { 
        if(($item.metadata).name -eq $serviceName) { 
            return ($item.spec).ports.nodePort
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
        $apiReq = "curl $podIP:8090/failreadinessprobe -UseBasicParsing"
        if($useIPV6) {
            $apiReq = "curl [$podIP]:8090/failreadinessprobe -UseBasicParsing"
        }
        $result = kubectl exec $clientName -n $namespace -- powershell -command $apiReq
        Log "FailReadiness Probe for $podIP status : $result"
    }

    WaitForPodsToBeNonReady -namespace $namespace -deployment $serverDeploymentName

    Log "Failing readiness probe for all server pods completed."
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
        $apiReq = "curl $podIP:8090/passreadinessprobe -UseBasicParsing"
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