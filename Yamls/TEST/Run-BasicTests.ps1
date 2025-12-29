$namespace = "demo"
$hpcDaemonsSet = "hpc-ds-win"
$serverPodDeployment = "tcp-server"
$retry = 2
$testLogsPath = ".\ConnectivityLogs.txt"

$RunClusterIPTests = $true
$RunNodePortTests = $true
$RunLoadBalancerTests = $true
$RunPolicyValidation = $true

$SvcTypeClusterIP = "CLUSTER-IP"
$SvcTypeNodePort = "NODE-PORT"
$SvcTypeLoadBalancer = "LOAD-BALANCER"
$SvcTypeKubeProxyErrorCheck = "KUBE-PROXY-ERROR-CHECK"

$SourceTypePod = "Pod"
$SourceTypeNode = "Node"
$SourceTypeExternal = "External"
$SourceTypePolicyCheck = "POLICY-CHECK"

$printLogs = $false

$ServiceInfo = [PSCustomObject]@{
    Name         = $null
    ExternalIP   = $null
    ExternalPort = $null
    Protocol     = $null
}

$ServicesMap = @{
    $SvcTypeClusterIP     = @()
    $SvcTypeNodePort      = @()
    $SvcTypeLoadBalancer  = @()
}

function Log {
    param(
        [string]$Message,
        [object]$InputObject,
        [string]$Color = "White"
    )

    if ($printLogs) {
        Write-Host "[LOG] $Message" -ForegroundColor $Color
        if ($InputObject) {
            Write-Host $InputObject
        }
    }
}

function Get-IPAddressType {
    param([string]$IPString)

    $parsedIP = $null
    # TryParse returns True if successful, False otherwise
    $isValid = [System.Net.IPAddress]::TryParse($IPString, [ref]$parsedIP)

    if ($isValid) {
        if ($parsedIP.AddressFamily -eq 'InterNetwork') {
            return "IPv4"
        } elseif ($parsedIP.AddressFamily -eq 'InterNetworkV6') {
            return "IPv6"
        }
    } else {
        return "Invalid IP Address"
    }
}

# Returns a map of HPC Pod Names to Node Names
function Get-AllHpcPods {
    $items = (kubectl get pods -n $namespace -l name=$hpcDaemonsSet -o json | ConvertFrom-Json).items
    $Global:allHpcPods = @{}
    foreach ($item in $items) {
        $podName = $item.metadata.name
        $nodeName = $item.spec.nodeName
        $Global:allHpcPods[$podName] = $nodeName
    }
    Log -Message "HPC DaemonSet Pods found:" -InputObject $Global:allHpcPods
    return $Global:allHpcPods
}

# Returns a map of Server Pod Names to Node Names
function Get-AllServerPods {
    $items = (kubectl get pods -n $namespace -l app=$serverPodDeployment -o json | ConvertFrom-Json).items
    $allServerPods = @{}
    foreach ($item in $items) {
        $podName = $item.metadata.name
        $nodeName = $item.spec.nodeName
        $allServerPods[$podName] = $nodeName
    }
    Log -Message "Server Pods found:" -InputObject $allServerPods
    return $allServerPods
}

# Returns a map of NodeIP to NodeName for Windows nodes
function Get-AllNodeIPs {
    $items = (kubectl get nodes -o json | ConvertFrom-Json).items
    $nodeIPs = @{}
    foreach ($item in $items) {
        if ($item.metadata.labels.'kubernetes.io/os' -ne 'windows') {
            continue
        }
        $addresses = $item.status.addresses
        foreach ($address in $addresses) {
            if ($address.type -eq 'InternalIP') {
                $nodeIPs[$address.address] = $item.metadata.name
            }
        }
    }
    Log -Message "Node IPs found:" -InputObject $nodeIPs
    return $nodeIPs
}

function Get-AllServices {
    $servicesMap = $ServicesMap.Clone()
    $Global:allServices = (kubectl get svc -n $namespace -o json | ConvertFrom-Json).items
    $allNodeIPs = (Get-AllNodeIPs).Keys

    foreach ($svc in $Global:allServices) {
        $name = $svc.metadata.name
        $externalPorts = $svc.spec.ports.port
        $nodePorts = $svc.spec.ports.nodePort
        $clusterIPS = $svc.spec.clusterIPs
        $ingressIps = $svc.status.loadBalancer.ingress
        $ipFamilies = $svc.spec.ipFamilies

        # Constructing ClusterIP Services
        foreach ($clusterIP in $clusterIPS) {
            foreach ($externalPort in $externalPorts) {
                $serviceInfo = [PSCustomObject]@{
                    Name         = $name
                    ExternalIP   = $clusterIP
                    ExternalPort = $externalPort
                }
                $servicesMap[$SvcTypeClusterIP] += $serviceInfo
            }
        }

        # Constructing NodePort Services
        foreach ($nodePort in $nodePorts) {
            foreach ($externalPort in $externalPorts) {
                foreach ($nodeIP in $allNodeIPs) {
                    $ipAddrType = Get-IPAddressType -IPString $nodeIP
                    if (($ipFamilies.Count -eq 1) -and ($ipFamilies[0] -ne $ipAddrType)) {
                        continue
                    }
                    $serviceInfo = [PSCustomObject]@{
                        Name         = $name
                        ExternalIP   = $nodeIP
                        ExternalPort = $nodePort
                    }
                    $servicesMap[$SvcTypeNodePort] += $serviceInfo
                }
            }
        }

        # Constructing LoadBalancer Services
        foreach ($ingress in $ingressIps) {
            foreach ($externalPort in $externalPorts) {
                $serviceInfo = [PSCustomObject]@{
                    Name         = $name
                    ExternalIP   = $ingress.ip
                    ExternalPort = $externalPort
                }
                $servicesMap[$SvcTypeLoadBalancer] += $serviceInfo
            }
        }

    }
    
    Log -Message "Services Map constructed:" -InputObject $servicesMap
    return $servicesMap
}

function Get-HnsPolicies {
    $policies = @{}
    $allHpcPods = Get-AllHpcPods
    foreach ($pod in $allHpcPods.Keys) {
        $policyJson = kubectl exec -n $namespace $pod -- powershell -Command "Get-HnsPolicyList | ConvertTo-Json -Depth 10"
        $policies[$pod] = $policyJson | ConvertFrom-Json
    }
    Log -Message "HNS Policies collected from HPC Pods:" -InputObject $policies
    return $policies
}

function Validate-HnsPolicy {
    param(
        [string]$SvcType
    )
    $services = $Global:allServices[$SvcType]
    foreach ($HpcPodName in $Global:allHpcPods.Keys) {
        $hnsPolicies = $Global:hnsPolicies[$HpcPodName]
        $policies = $hnsPolicies.Policies
        foreach ($service in $services) {
            $matchCount = 0
            foreach ($policy in $policies) {
                if ($SvcType -Eq $SvcTypeNodePort) {
                    if ($policy.ExternalPort -Eq $service.ExternalPort) {
                        $matchCount++
                    }
                } else {
                    if ($policy.ExternalPort -Eq $service.ExternalPort -and $policy.VIPs[0] -Eq $service.ExternalIP) {
                        $matchCount++
                    }
                }
            }
            Log-Result -TestType $SvcType -Source $HpcPodName -SourceType $SourceTypePolicyCheck -service $service -IsSuccess ($matchCount -gt 0) -cmd "N/A"
        }
    }
    Write-Host "`n"
}

function Validate-KubeProxyErrors {
    $errors = @(
        "IP address is either invalid",
        "network was not found",
        "endpoint was not found",
        "The specified port already exists"
    )
    $allHpcPods = Get-AllHpcPods
    foreach ($pod in $allHpcPods.Keys) {
        $kubeProxyLogs = kubectl exec -n $namespace $pod -- powershell -Command "Get-Content C:\k\kubeproxy.err.log"
        foreach($err in $errors) {
            $errorCount = ($kubeProxyLogs | Select-String -Pattern $err).Count
            Log-Result -TestType $SvcTypeKubeProxyErrorCheck -Source $pod -SourceType $SourceTypePolicyCheck -IsSuccess ($errorCount -eq 0) -cmd "Error: $err, Error Count: $errorCount"
        }
    }
    Write-Host "`n"
}

$Global:index = 0
$Global:successTests = @()
$Global:failedTests = @()

function Log-Result {
    param(
        [string]$TestType,
        [string]$Source,
        [string]$SourceType,
        [object]$service,
        [string]$IsSuccess,
        [string]$Cmd
    )
    $Global:index++
    if ($SourceType -eq $SourceTypePolicyCheck) {
        $Direction = $SourceTypePolicyCheck
    } else {
        $Direction = "$SourceType->$TestType"
    }
    $NodeName = $Global:allHpcPods[$Source]
    If ($null -Eq $NodeName) {
        $NodeName = $Global:allServerPods[$Source]
    }
    If ($null -ne $NodeName) {
        $NodeName = "Node: $NodeName"
    } else {
        $NodeName = ""
    }

    if ($TestType -eq $SvcTypeKubeProxyErrorCheck) {
        $LogString = "[$SvcTypeKubeProxyErrorCheck]: $NodeName, Source: $Source, $cmd"
    } else {
        $LogString = "[$($service.Name)]: $NodeName, Source: $Source, TargetIP: $($service.ExternalIP), TargetPort: $($service.ExternalPort)"
    }
    
    if ($IsSuccess -eq $true) {
        $msg = "[TEST-$($Global:index)][SUCCESS][$Direction]$LogString"
        Write-Host "$msg" -ForegroundColor Green
        $Global:successTests += $msg
    } else {
        if ($TestType -ne $SvcTypeKubeProxyErrorCheck) {
            $LogString += " Command: [$Cmd]"
        }
        $msg =  "[TEST-$($Global:index)][FAILURE][$Direction]$LogString"
        Write-Host "$msg" -ForegroundColor Red
        $Global:failedTests += $msg
    }
}

function Print-PodsAndServices {
    Write-Host ""
    Write-Host "================================"
    Write-Host "All Node IPs" -ForegroundColor Cyan
    Write-Host "================================"
    $Global:allNodeIPs | Format-Table
    Write-Host "================================"
    Write-Host "All HPC Pods" -ForegroundColor Cyan
    Write-Host "================================"
    $Global:allHpcPods | Format-Table
    Write-Host "================================"
    Write-Host "All Server Pods" -ForegroundColor Cyan
    Write-Host "================================"
    $Global:allServerPods | Format-Table
    Write-Host "All ClusterIP Services" -ForegroundColor Cyan
    Write-Host "================================"
    $Global:allServices[$SvcTypeClusterIP] | Format-Table
    Write-Host "================================"
    Write-Host "All NodePort Services" -ForegroundColor Cyan
    Write-Host "================================"
    $Global:allServices[$SvcTypeNodePort] | Format-Table
    Write-Host "================================"
    Write-Host "All Loadbalancer Services" -ForegroundColor Cyan
    Write-Host "================================"
    $Global:allServices[$SvcTypeLoadBalancer] | Format-Table
    Write-Host "================================"
}

function Log-PodsAndServices {
    Write-Output "================================" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "All Node IPs" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "================================" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    $Global:allNodeIPs | Format-Table | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "================================" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "All HPC Pods" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "================================" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    $Global:allHpcPods | Format-Table | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "================================" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "All Server Pods" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "================================" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    $Global:allServerPods | Format-Table | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "All ClusterIP Services" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "================================" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    $Global:allServices[$SvcTypeClusterIP] | Format-Table | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "================================" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "All NodePort Services" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "================================" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    $Global:allServices[$SvcTypeNodePort] | Format-Table | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "================================" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "All Loadbalancer Services" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "================================" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    $Global:allServices[$SvcTypeLoadBalancer] | Format-Table | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    Write-Output "================================" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
}

function Log-TestSummary {
    # Printing successful tests summary
    if ($Global:successTests.Count -gt 0) {
        Write-Output "`n================================" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
        Write-Output "`nSummary of Successful Tests: $($Global:successTests.Count) `n" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
        foreach ($successTest in $Global:successTests) {
            Write-Output $successTest | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
        }
    }
    # Printing failed tests summary
    if ($Global:failedTests.Count -gt 0) {
        Write-Output "`n================================" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
        Write-Output "`nSummary of Failed Tests: $($Global:failedTests.Count) `n" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
        foreach ($failedTest in $Global:failedTests) {
            Write-Output $failedTest | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
        }
    } else {
        Write-Output "`nAll tests passed successfully!`n" | Out-File -FilePath $testLogsPath -Encoding utf8 -Append
    }
}

function Print-TestSummary {
    # Printing successful tests summary
    if ($Global:successTests.Count -gt 0) {
        Write-Host "`n================================" -ForegroundColor Green
        Write-Host "`nSummary of Successful Tests: $($Global:successTests.Count) `n" -ForegroundColor Green
        foreach ($successTest in $Global:successTests) {
            Write-Host $successTest -ForegroundColor Green
        }
    }
    # Printing failed tests summary
    if ($Global:failedTests.Count -gt 0) {
        Write-Host "`n================================" -ForegroundColor Red
        Write-Host "`nSummary of Failed Tests: $($Global:failedTests.Count) `n" -ForegroundColor Red
        foreach ($failedTest in $Global:failedTests) {
            Write-Host $failedTest -ForegroundColor Red
        }
    } else {
        Write-Host "`nAll tests passed successfully!`n" -ForegroundColor Green
    }
}

$Global:allHpcPods = Get-AllHpcPods
$Global:allServices = Get-AllServices
$Global:allServerPods = Get-AllServerPods
$Global:allNodeIPs = Get-AllNodeIPs
$Global:hnsPolicies = Get-HnsPolicies

Print-PodsAndServices

Write-Host "`nStarting Service Connectivity Tests...`n" -ForegroundColor Magenta

if ($RunClusterIPTests) {
    # Running tests for ClusterIP Services
    Write-Host "`nRunning tests for ClusterIP Services..." -ForegroundColor Cyan
    Write-Host "`n"

    foreach ($service in $Global:allServices[$SvcTypeClusterIP]) {
        $nodeTested = @{}
        # Pod to ClusterIP Tests
        foreach ($pod in $Global:allServerPods.Keys) {
            $nodeNameFromPod = $Global:allServerPods[$pod]
            if ($nodeTested.ContainsKey($nodeNameFromPod)) {
                Log -Message "Skipping ClusterIP test from Server Pod: '$pod' on Node: '$nodeNameFromPod' to Service '$($service.Name)' at $($service.ExternalIP):$($service.ExternalPort) as this node has already been tested." -Color DarkGray
                continue
            }
            $nodeTested[$nodeNameFromPod] = $true
            Log -Message "Testing ClusterIP connectivity from Pod: '$pod' to Service '$($service.Name)' at $($service.ExternalIP):$($service.ExternalPort)..." -Color Yellow
            $cmd = "kubectl exec -n $namespace $pod -- powershell -Command 'Test-NetConnection $($service.ExternalIP) -Port $($service.ExternalPort) | Select-Object -ExpandProperty TcpTestSucceeded'"
            for($i = 1; $i -le $retry; $i++) {
                $ok = kubectl exec -n $namespace $pod -- powershell -Command "Test-NetConnection $($service.ExternalIP) -Port $($service.ExternalPort) | Select-Object -ExpandProperty TcpTestSucceeded"
                if ($ok -eq $true) { break }
            }
            Log-Result -TestType $SvcTypeClusterIP -Source $pod -SourceType $SourceTypePod -service $service -IsSuccess $ok -cmd $cmd
        }
        # Node to ClusterIP Tests
        foreach ($pod in $Global:allHpcPods.Keys) {
            Log -Message "Testing ClusterIP connectivity from HPC Pod: '$pod' to Service '$($service.Name)' at $($service.ExternalIP):$($service.ExternalPort)..." -Color Yellow
            $cmd = "kubectl exec -n $namespace $pod -- powershell -Command 'Test-NetConnection $($service.ExternalIP) -Port $($service.ExternalPort) | Select-Object -ExpandProperty TcpTestSucceeded'"
            for($i = 1; $i -le $retry; $i++) {
                $ok = kubectl exec -n $namespace $pod -- powershell -Command "Test-NetConnection $($service.ExternalIP) -Port $($service.ExternalPort) | Select-Object -ExpandProperty TcpTestSucceeded"
                if ($ok -eq $true) { break }
            }
            Log-Result -TestType $SvcTypeClusterIP -Source $pod -SourceType $SourceTypeNode -service $service -IsSuccess $ok -cmd $cmd
        }

    }

    Write-Host "`n"
}

if ($RunNodePortTests) {
    # Running tests for NodePort Services
    Write-Host "`nRunning tests for NodePort Services..." -ForegroundColor Cyan
    Write-Host "`n"

    foreach ($service in $Global:allServices[$SvcTypeNodePort]) {
        $nodeTested = @{}
        $nodeNameFromNodeIP = $Global:allNodeIPs[$service.ExternalIP]
        # Pod to NodePort Tests
        foreach ($pod in $Global:allServerPods.Keys) {
            $nodeNameFromPod = $Global:allServerPods[$pod]
            if ($nodeNameFromPod -ne $nodeNameFromNodeIP) {
                Log -Message "Skipping NodePort test from Server Pod: '$pod' on Node: '$nodeNameFromPod' to Service '$($service.Name)' at $($service.ExternalIP):$($service.ExternalPort) as they are on different nodes." -Color DarkGray
                continue
            }
            if ($nodeTested.ContainsKey($nodeNameFromPod)) {
                Log -Message "Skipping NodePort test from Server Pod: '$pod' on Node: '$nodeNameFromPod' to Service '$($service.Name)' at $($service.ExternalIP):$($service.ExternalPort) as this node has already been tested." -Color DarkGray
                continue
            }
            $nodeTested[$nodeNameFromPod] = $true
            Log -Message "Testing NodePort connectivity from Pod: '$pod' to Service '$($service.Name)' at $($service.ExternalIP):$($service.ExternalPort)..." -Color Yellow
            $cmd = "kubectl exec -n $namespace $pod -- powershell -Command 'Test-NetConnection $($service.ExternalIP) -Port $($service.ExternalPort) | Select-Object -ExpandProperty TcpTestSucceeded'"
            for($i = 1; $i -le $retry; $i++) {
                $ok = kubectl exec -n $namespace $pod -- powershell -Command "Test-NetConnection $($service.ExternalIP) -Port $($service.ExternalPort) | Select-Object -ExpandProperty TcpTestSucceeded"
                if ($ok -eq $true) { break }
            }
            Log-Result -TestType $SvcTypeNodePort -Source $pod -SourceType $SourceTypePod -service $service -IsSuccess $ok -cmd $cmd
        }
        # Node to NodePort Tests
        foreach ($pod in $Global:allHpcPods.Keys) {
            $nodeNameFromPod = $Global:allHpcPods[$pod]
            if ($nodeNameFromPod -ne $nodeNameFromNodeIP) {
                Log -Message "Skipping NodePort test from HPC Pod: '$pod' on Node: '$nodeNameFromPod' to Service '$($service.Name)' at $($service.ExternalIP):$($service.ExternalPort) as they are on different nodes." -Color DarkGray
                continue
            }
            Log -Message "Testing NodePort connectivity from Pod: '$pod' to Service '$($service.Name)' at $($service.ExternalIP):$($service.ExternalPort)..." -Color Yellow
            $cmd = "kubectl exec -n $namespace $pod -- powershell -Command 'Test-NetConnection $($service.ExternalIP) -Port $($service.ExternalPort) | Select-Object -ExpandProperty TcpTestSucceeded'"
            for($i = 1; $i -le $retry; $i++) {
                $ok = kubectl exec -n $namespace $pod -- powershell -Command "Test-NetConnection $($service.ExternalIP) -Port $($service.ExternalPort) | Select-Object -ExpandProperty TcpTestSucceeded"
                if ($ok -eq $true) { break }
                Start-Sleep -Seconds 1
            }
            Log-Result -TestType $SvcTypeNodePort -Source $pod -SourceType $SourceTypeNode -service $service -IsSuccess $ok -cmd $cmd
        }

    }

    Write-Host "`n"
}

if ($RunLoadBalancerTests) {
    # Running tests for LoadBalancer Services
    Write-Host "`nRunning tests for LoadBalancer Services..." -ForegroundColor Cyan
    Write-Host "`n"

    foreach ($service in $Global:allServices[$SvcTypeLoadBalancer]) {
        $nodeTested = @{}
        # Pod to IngressIP Tests
        foreach ($pod in $Global:allServerPods.Keys) {
            $nodeNameFromPod = $Global:allServerPods[$pod]
            if ($nodeTested.ContainsKey($nodeNameFromPod)) {
                Log -Message "Skipping LoadBalancer test from Server Pod: '$pod' on Node: '$nodeNameFromPod' to Service '$($service.Name)' at $($service.ExternalIP):$($service.ExternalPort) as this node has already been tested." -Color DarkGray
                continue
            }
            $nodeTested[$nodeNameFromPod] = $true
            Log -Message "Testing LoadBalancer connectivity from Server Pod: '$pod' to Service '$($service.Name)' at $($service.ExternalIP):$($service.ExternalPort)..." -Color Yellow
            $cmd = "kubectl exec -n $namespace $pod -- powershell -Command 'Test-NetConnection $($service.ExternalIP) -Port $($service.ExternalPort) | Select-Object -ExpandProperty TcpTestSucceeded'"
            for($i = 1; $i -le $retry; $i++) {
                $ok = kubectl exec -n $namespace $pod -- powershell -Command "Test-NetConnection $($service.ExternalIP) -Port $($service.ExternalPort) | Select-Object -ExpandProperty TcpTestSucceeded"
                if ($ok -eq $true) { break }
                Start-Sleep -Seconds 1
            }
            Log-Result -TestType $SvcTypeLoadBalancer -Source $pod -SourceType $SourceTypePod -service $service -IsSuccess $ok -cmd $cmd
        }
        # Node to IngressIP Tests
        foreach ($pod in $Global:allHpcPods.Keys) {
            Log -Message "Testing LoadBalancer connectivity from HPC Pod: '$pod' to Service '$($service.Name)' at $($service.ExternalIP):$($service.ExternalPort)..." -Color Yellow
            $cmd = "kubectl exec -n $namespace $pod -- powershell -Command 'Test-NetConnection $($service.ExternalIP) -Port $($service.ExternalPort) | Select-Object -ExpandProperty TcpTestSucceeded'"
            for($i = 1; $i -le $retry; $i++) {
                $ok = kubectl exec -n $namespace $pod -- powershell -Command "Test-NetConnection $($service.ExternalIP) -Port $($service.ExternalPort) | Select-Object -ExpandProperty TcpTestSucceeded"
                if ($ok -eq $true) { break }
                Start-Sleep -Seconds 1
            }
            Log-Result -TestType $SvcTypeLoadBalancer -Source $pod -SourceType $SourceTypeNode -service $service -IsSuccess $ok -cmd $cmd
        }
        # External to IngressIP Tests
        Log -Message "Testing LoadBalancer connectivity from External to Service '$($service.Name)' at $($service.ExternalIP):$($service.ExternalPort)..." -ForegroundColor Yellow
        $cmd = "powershell -Command 'Test-NetConnection $($service.ExternalIP) -Port $($service.ExternalPort) | Select-Object -ExpandProperty TcpTestSucceeded'"
        for($i = 1; $i -le $retry; $i++) {
            $ok = powershell -Command "Test-NetConnection $($service.ExternalIP) -Port $($service.ExternalPort) | Select-Object -ExpandProperty TcpTestSucceeded"
            if ($ok -eq $true) { break }
            Start-Sleep -Seconds 1
        }
        Log-Result -TestType $SvcTypeLoadBalancer -Source "External" -SourceType $SourceTypeExternal -service $service -IsSuccess $ok -cmd $cmd
    }

    Write-Host "`n"
}

if ($RunPolicyValidation) {
    Write-Host "`nRunning HNS Policy Validation Tests..." -ForegroundColor Cyan
    Write-Host "`n"
    Validate-HnsPolicy -SvcType $SvcTypeClusterIP
    Validate-HnsPolicy -SvcType $SvcTypeNodePort
    Validate-HnsPolicy -SvcType $SvcTypeLoadBalancer
    Validate-KubeProxyErrors
}

rm -Force $testLogsPath -ErrorAction SilentlyContinue

Write-Host "TEST RESULTS SUMMARY" -ForegroundColor Magenta

Log-PodsAndServices

Log-TestSummary

Print-TestSummary