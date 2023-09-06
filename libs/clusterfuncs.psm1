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
    $status = az group create --name $clusterInfo.RgName --location $clusterInfo.Location
    if($null -eq $status) {
        Write-Host "Resource group creation failed" -ForegroundColor Red
        return "FAILED"
    }

    Log "Creating Aks Cluster."
    $rgName = $clusterInfo.RgName
    $clusterName = $clusterInfo.Name
    $npmName = $clusterInfo.Npm
    $nwPluginName = $clusterInfo.NwPlugin
    $nwPluginMode = $clusterInfo.NwPluginMode
    $k8sVersion = $clusterInfo.K8sVersion
    $nodeUserName = $clusterInfo.NodeUsername
    $NodePassword = $clusterInfo.NodePassword
    $ControlNodeOsSku = $clusterInfo.ControlNodeOsSku

    $aksCreateCmd = "az aks create --resource-group $rgName --name $clusterName --node-count 1"
    if(($null -ne $nodeUserName) -and ($null -ne $NodePassword) -and ($nodeUserName -ne "") -and ($NodePassword -ne "")) {
        $aksCreateCmd = $aksCreateCmd + " --windows-admin-username $nodeUserName --windows-admin-password $NodePassword"
    }
    # $aksCreateCmd = "az aks create --resource-group $rgName --name $clusterName --generate-ssh-keys --vm-set-type VirtualMachineScaleSets"

    if($null -ne $k8sVersion -and $k8sVersion -ne "") {
        $aksCreateCmd = $aksCreateCmd + " --kubernetes-version $k8sVersion" 
    }

    if($null -ne $ControlNodeOsSku -and $ControlNodeOsSku -ne "") {
        $aksCreateCmd = $aksCreateCmd + " --os-sku $ControlNodeOsSku" 
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

    $status = powershell.exe $aksCreateCmd
    if($null -eq $status) {
        Write-Host "AKS Cluster Create failed" -ForegroundColor Red
        return "FAILED"
    }

    Log "Creating Node Pool."
    $status = az aks nodepool add --resource-group $clusterInfo.RgName --cluster-name $clusterInfo.Name --os-type Windows --os-sku $clusterInfo.OsSku --name $clusterInfo.NodePoolName --node-count $clusterInfo.NodeCount
    if($null -eq $status) {
        Write-Host "Node Pool creation failed" -ForegroundColor Red
        return "FAILED"
    }

    Log "Retrieving Credentials"
    az aks get-credentials --resource-group $clusterInfo.RgName --name $clusterInfo.Name --overwrite-existing
    Log "Nodes"
    kubectl get nodes -o wide
    Log "AKS Cluster Deployment Completed."

    if($clusterInfo.EnableRdp) {
        EnableRdp -clusterInfo $clusterInfo
    }

    return "SUCCESS"
}

function EnableRdp {
    param (
        [Parameter (Mandatory = $true)] [System.Object]$clusterInfo
    )

    Log "RDP VM creation initiated."

    $rgName = $clusterInfo.RgName
    $clusterName = $clusterInfo.Name
    $username = $clusterInfo.NodeUsername
    $password = $clusterInfo.NodePassword
    $rdpVmName = "MyRdpVm"
    $image = "win2022datacenter"
    $nsgRuleName = "TempRdpAccess"

    $nodeRgName = az aks show -g $rgName -n $clusterName --query nodeResourceGroup -o tsv
    $vnetName = az network vnet list -g $nodeRgName --query [0].name -o tsv
    $vnetSubnetName = az network vnet subnet list -g $nodeRgName --vnet-name $vnetName --query [0].name -o tsv
    $vnetSubnetId = az network vnet subnet show -g $nodeRgName --vnet-name $vnetName --name $vnetSubnetName --query id -o tsv
    $rdpVmIP = az vm create --resource-group $rgName --name $rdpVmName --image $image --admin-username $username --admin-password $password --subnet $vnetSubnetId --nic-delete-option delete --os-disk-delete-option delete --public-ip-address "myVMPublicIP" --query publicIpAddress -o tsv

    $nsgName = az network nsg list -g $nodeRgName --query [].name -o tsv
    $status = az network nsg rule create --name $nsgRuleName --resource-group $nodeRgName --nsg-name $nsgName --priority 100 --destination-port-range 3389 --protocol Tcp --description "Temporary RDP access to Windows nodes"

    if($null -ne $status) {
        Log "RDP VM Ready. Details : VM IP : $rdpVmIP , Username : $username , Password : $password"
    }

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
