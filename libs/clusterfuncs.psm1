Import-Module -Force .\libs\utils.psm1

function InstallCluster {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$clusterInfo
    )
    Log "AKS Cluster Deployment Started."
    Log "Info : $clusterInfo"
    Log "Setting Subscription."
    az account set --subscription $clusterInfo.SubscriptionId
    Log "Creating Resource Group."
    az group create --name $clusterInfo.RgName --location $clusterInfo.Location
    Log "Creating Aks Cluster."
    if($clusterInfo.Npm -eq "") {
        az aks create --resource-group $clusterInfo.RgName --name $clusterInfo.Name --node-count 1 --generate-ssh-keys --vm-set-type VirtualMachineScaleSets --network-plugin azure
    } else {
        az aks create --resource-group $clusterInfo.RgName --name $clusterInfo.Name --node-count 1 --generate-ssh-keys --vm-set-type VirtualMachineScaleSets --network-plugin azure --network-policy $clusterInfo.Npm
    }
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
