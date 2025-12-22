param(
    [Parameter(Mandatory=$true)]
    [string]$DstPath
)

$namespace = "demo"
$hpcDaemonsSet = "hpc-ds-win"
$RootDir = "C:\Users\ppereira\Logs\Bugs\Cilium\KubeProxyDualStackbehav"
$FolderPath = Join-Path -Path $RootDir -ChildPath $DstPath
if (-Not (Test-Path -Path $FolderPath)) {
    New-Item -ItemType Directory -Path $FolderPath | Out-Null
}
rm -r -Force "$FolderPath\*" -ErrorAction SilentlyContinue

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

$allHpcPods = Get-AllHpcPods
foreach ($pod in $allHpcPods) {
    Write-Host "Collecting Windows Logs from Pod: $pod" -ForegroundColor Yellow
    Write-Host "Copying collect script to Pod: $pod" -ForegroundColor DarkYellow
    kubectl cp -n $namespace .\collectlogs.ps1 $pod`:collectlogs.ps1
    Write-Host "Executing collect script in Pod: $pod" -ForegroundColor DarkYellow
    kubectl exec -n $namespace $pod -- powershell -Command ".\collectlogs.ps1"
    Write-Host "Copying logs.zip from Pod: $pod" -ForegroundColor DarkYellow
    kubectl cp -n $namespace $pod`:logs.zip "$pod.zip"
    move-item -Force "$pod.zip" "$FolderPath\$pod.zip"
    Write-Host "Finished collecting logs from Pod: $pod" -ForegroundColor Green
}

Write-Host "All logs collected and stored in folder: $FolderPath" -ForegroundColor Magenta