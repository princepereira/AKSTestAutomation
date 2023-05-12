Import-Module -Force .\libs\utils.psm1

function InstallCluster {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$clusterInfo
    )
    az login
    Log "AKS Cluster Deployment Started."
    Log "Info : $clusterInfo"
    Log "Setting Subscription."
    az account set --subscription $clusterInfo.SubscriptionId
    Log "Creating Resource Group."
    az group create --name $clusterInfo.RgName --location $clusterInfo.Location
    Log "Creating Aks Cluster."
    $rgName = $clusterInfo.RgName
    $clusterName = $clusterInfo.Name
    $npmName = $clusterInfo.Npm
    $nwPluginName = $clusterInfo.NwPlugin
    $nwPluginMode = $clusterInfo.NwPluginMode
    $k8sVersion = $clusterInfo.K8sVersion

    $aksCreateCmd = "az aks create --resource-group $rgName --name $clusterName --node-count 1 --generate-ssh-keys --vm-set-type VirtualMachineScaleSets"

    if($null -ne $k8sVersion -and $k8sVersion -ne "") {
        $aksCreateCmd = $aksCreateCmd + " --kubernetes-version $k8sVersion" 
    }

    if($null -ne $nwPluginMode -and $nwPluginMode -ne "") {
        $aksCreateCmd = $aksCreateCmd + " --network-plugin-mode $nwPluginMode"
    }

    if($null -eq $nwPluginName -or $nwPluginName -eq "") {
        $aksCreateCmd = $aksCreateCmd + " --network-plugin azure"
    } else {
        $aksCreateCmd = $aksCreateCmd + " --network-plugin $nwPluginName"
    }

    if($null -ne $clusterInfo.IsDualStack -and $clusterInfo.IsDualStack -eq $true) {
        $aksCreateCmd = $aksCreateCmd + " --ip-families ipv4,ipv6"
    }

    if($null -ne $npmName -and $npmName -ne "") {
        $aksCreateCmd = $aksCreateCmd + " --network-policy $npmName"
    }
    
    Write-Host "AKS Cluster Create Command Executed : $aksCreateCmd"

    powershell.exe $aksCreateCmd

    Log "Creating Node Pool."
    az aks nodepool add --resource-group $clusterInfo.RgName --cluster-name $clusterInfo.Name --os-type Windows --os-sku $clusterInfo.OsSku --name $clusterInfo.NodePoolName --node-count $clusterInfo.NodeCount
    Log "Retrieving Credentials"
    az aks get-credentials --resource-group $clusterInfo.RgName --name $clusterInfo.Name --overwrite-existing
    Log "Nodes"
    kubectl get nodes -o wide
    Log "AKS Cluster Deployment Completed."
}

function GetClusterCredentials {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$clusterInfo
    )
    Log "Setting Subscription."
    az account set --subscription $clusterInfo.SubscriptionId
    Log "Retrieving Credentials"
    az aks get-credentials --resource-group $clusterInfo.RgName --name $clusterInfo.Name --overwrite-existing
    Log "Nodes"
    kubectl get nodes -o wide
}

function UninstallCluster {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$clusterInfo
    )
    Log "AKS Cluster Uninstall Started."
    az account set --subscription $clusterInfo.SubscriptionId
    az group delete --name $clusterInfo.RgName -y
    kubectl config delete-context $clusterInfo.Name
    Log "AKS Cluster Uninstall Completed."
}
