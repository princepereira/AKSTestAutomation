Import-Module -Force .\libs\utils.psm1

function InstallApps {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$appInfo
    )
    Log "App Install Started."
    $namespace = $appInfo.Namespace
    kubectl create namespace $namespace

    if(($appInfo.HpcDaemonsetName).Contains("22")) {
        kubectl create -f .\Yamls\HPC\hpc-ds-win22.yaml
        if(!(WaitForPodsToBeReady -namespace $appInfo.HpcNamespace)) {
            Log "Containers didn't come up."
            return $false
        }
        CopyTcpClientToNodes -namespace $appInfo.HpcNamespace -deploymentName $appInfo.HpcDaemonsetName
    }

    if($appInfo.InstallIPv4Required) {
        kubectl create -f .\Yamls\IPV4
    }

    if($appInfo.InstallIPv6Required) {
        kubectl create -f .\Yamls\IPV6
    }

    kubectl create -f .\Yamls
    if(!(WaitForPodsToBeReady -namespace $namespace)) {
        Log "Containers didn't come up."
        return $false
    }
    Log "Pods"
    kubectl get pods -o wide -n $namespace
    if(!(WaitForServicesToBeReady -namespace $namespace)) {
        Log "Services didn't come up."
        return $false
    }
    Log "Services"
    kubectl get services -o wide -n $namespace
    Log "App Install Completed."
}

function UninstallApps {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace
    )
    Log "App Uninstall Started."
    kubectl delete -f .\Yamls
    kubectl delete -f .\Yamls\IPV4
    kubectl delete -f .\Yamls\IPV6
    kubectl delete -f .\Yamls\HPC
    Start-Sleep -Seconds 10
    kubectl delete namespace $namespace --force=true
    Start-Sleep -Seconds 10
    Log "App Uninstall Completed."
}
