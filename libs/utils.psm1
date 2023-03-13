$Global:nodePoolName = "npwin"

function Log {
    param (
        [Parameter (Mandatory = $true)] [String]$logMsg
    )
    Write-Host " "
    Write-Host "#========= $logMsg "
}

function GetClientName {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$deploymentName
    )
    $metadatas = ((kubectl get pods -n $namespace -o json | ConvertFrom-Json).Items).metadata
    foreach($metadata in $metadatas) { 
        if(($metadata.labels).app -eq $deploymentName ) { 
            return $metadata.name 
        } 
    }
    return ""
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
    if($expPodCount -ge $podCount) {
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

function LogResult {
    param (
        [Parameter (Mandatory = $true)] [String]$logPath,
        [Parameter (Mandatory = $true)] [String]$testcaseName,
        [Parameter (Mandatory = $true)] [String]$index,
        [Parameter (Mandatory = $true)] [String]$expectedResult,
        [Parameter (Mandatory = $true)] [String]$actualResult
    )
    if($actualResult.Contains($expectedResult)) {
        $result = "Testcase $index : $testcaseName - PASSED"
    } else {
        $result = "Testcase $index : $testcaseName - FAILED . Remarks : $actualResult"
    }
    Log $result
    Add-content $logPath -value $result
}

function LogPingResult {
    param (
        [Parameter (Mandatory = $true)] [String]$logPath,
        [Parameter (Mandatory = $true)] [String]$testcaseName,
        [Parameter (Mandatory = $true)] [String]$index,
        [Parameter (Mandatory = $true)] [String]$result
    )
    if($result.Contains("True")) {
        $result = "Testcase $index : $testcaseName - PASSED"
    } else {
        $result = "Testcase $index : $testcaseName - FAILED . Remarks : $result"
    }
    Log $result
    Add-content $logPath -value $result
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
        Start-Sleep -Seconds 3
    }
    return $false
}

function WaitForServicesToBeReady {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [Int32]$serviceCount
    )
    return $true
    $count = 200
    while ($count--) {
        $allReady = $true
        $ipList = ((((($svcJson).items).status).loadBalancer).ingress).ip
        foreach($ip in $ipList) {
            if($ip -eq "") {
                $allReady = $false
                break
            }
        }
        if($allReady -and ($ipList.Count -eq $serviceCount)) {
            return $true
        }
        Log "Waiting for Service to be Ready"
        Start-Sleep -Seconds 3
    }
    return $false
}
