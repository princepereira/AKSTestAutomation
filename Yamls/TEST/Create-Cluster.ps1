
$CreateRg = $false
$CreateSingleStackCluster = $false
$CreateDualStackCluster = $false
$CreateNodePool = $true


$subscriptionId="b8c06bcd-5024-43fa-9507-691b5623f59a"
$rgName="pper-vfptest-rg"
$location="westeurope"
$clusterName="pper-vfptest-aks"
$nodeUserName="prince"
$nodePassword="prince@123456123456"
$k8sVersion="1.32.7"
$nodePoolName="npwin"
$nodeCount="2"

if ($CreateRg) {
    Write-Host "Creating Resource Group: $rgName in Location: $location" -ForegroundColor Cyan
    az login
    az account set --subscription $subscriptionId
    az group create --name $rgName --location $location
}

if ($CreateSingleStackCluster) {
    Write-Host "Creating Single Stack AKS Cluster: $clusterName" -ForegroundColor Cyan
    az aks create --resource-group $rgName --name $clusterName --node-count 1 --windows-admin-username $nodeUserName --windows-admin-password $nodePassword --kubernetes-version $k8sVersion --os-sku AzureLinux --network-plugin-mode overlay --network-plugin azure
    az aks get-credentials --resource-group $rgName --name $clusterName --overwrite-existing
}

if ($CreateDualStackCluster) {
    Write-Host "Creating Dual Stack AKS Cluster: $clusterName" -ForegroundColor Cyan
    az aks create --resource-group $rgName --name $clusterName --node-count 1 --windows-admin-username $nodeUserName --windows-admin-password $nodePassword --kubernetes-version $k8sVersion --os-sku AzureLinux --network-plugin-mode overlay --network-plugin azure --ip-families ipv4,ipv6
    az aks get-credentials --resource-group $rgName --name $clusterName --overwrite-existing
}

if ($CreateNodePool) {
    Write-Host "Creating Windows Node Pool: $nodePoolName in Cluster: $clusterName" -ForegroundColor Cyan
    az aks nodepool add --resource-group $rgName --cluster-name $clusterName --os-type Windows --os-sku Windows2022 --node-vm-size standard_e8-2as_v5 --name $nodePoolName --node-count $nodeCount
    Write-Host "Waiting for 5 minutes for the nodes to be ready..." -ForegroundColor Yellow
}