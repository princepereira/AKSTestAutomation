$namespace = "demo"
$hpcDaemonsSet = "hpc-ds-win"

# Returns a map of HPC Pod Names to Node Names
function Get-AllHpcPods {
    $allHpcPods = (kubectl get pods -n $namespace -l name=$hpcDaemonsSet -o json | ConvertFrom-Json).items.metadata.name
    Write-Host "HPC Pods in Namespace '$namespace':" -ForegroundColor Cyan
    foreach ($pod in $allHpcPods) {
        $nodeName = (kubectl get pod $pod -n $namespace -o json | ConvertFrom-Json).spec.nodeName
        Write-Host "  Pod: $pod  -->  Node: $nodeName" -ForegroundColor Green
    }
    return $allHpcPods
}

Write-Host "Preparing kube-proxy package for deployment to HPC Pods" -ForegroundColor Yellow
rm -r -Force kubeproxy.zip -ErrorAction SilentlyContinue
$kubeProxyHash = (Get-FileHash -Path .\kube-proxy.exe).Hash
Compress-Archive kube-proxy.exe kubeproxy.zip -Force

$allHpcPods = Get-AllHpcPods
foreach ($pod in $allHpcPods) {
    Write-Host "Copying 'copykubeproxy.ps1' script to Pod: $pod" -ForegroundColor DarkYellow
    kubectl cp -n $namespace .\copykubeproxy.ps1 $pod`:copykubeproxy.ps1
    Write-Host "Copying 'sfpcopy.exe' and 'kubeproxy.zip' to Pod: $pod" -ForegroundColor DarkYellow
    kubectl cp -n $namespace .\sfpcopy.exe $pod`:sfpcopy.exe
    Write-Host "Copying 'kubeproxy.zip' to Pod: $pod" -ForegroundColor DarkYellow
    kubectl cp -n $namespace .\kubeproxy.zip $pod`:kubeproxy.zip
    Write-Host "Executing 'copykubeproxy.ps1' script in Pod: $pod" -ForegroundColor DarkYellow
    kubectl exec -n $namespace $pod -- powershell -Command ".\copykubeproxy.ps1"
    Write-Host "Finished updating kube-proxy in Pod: $pod." -ForegroundColor Green
}

Write-Host "Waiting 90 seconds for Pods to restart and KubeProxy service to come online..." -ForegroundColor Yellow
Start-Sleep -Seconds 90

foreach ($pod in $allHpcPods) {
    Write-Host "Verifying KubeProxy service status in Pod: $pod" -ForegroundColor DarkYellow
    kubectl exec -n $namespace $pod -- powershell -Command "Get-Service KubeProxy"
    $podKubeProxyHash = kubectl exec -n $namespace $pod -- powershell -Command "(Get-FileHash -Path C:\k\kube-proxy.exe).Hash"
    if ($podKubeProxyHash -eq $kubeProxyHash) {
        Write-Host "kube-proxy.exe successfully updated in Pod: $pod" -ForegroundColor Green
    } else {
        Write-Host "ERROR: kube-proxy.exe update failed in Pod: $pod" -ForegroundColor Red
    }
    Write-Host "Finished updating kube-proxy in Pod: $pod." -ForegroundColor Green
    Write-Host "Actual hash: $kubeProxyHash" -ForegroundColor Green
    Write-Host "PodKubeProxy Hash: $podKubeProxyHash" -ForegroundColor Green
}

Write-Host "All HPC Pods updated with new kube-proxy version." -ForegroundColor Magenta

kubectl get pods -n $namespace -o wide