# AKSTestAutomation
Automation framework for running AKS testcases.

#### How to run test framework

```
Modify testconf.json

Run testcases

PS> .\starttest.ps1

```

#### Supported Values

```
ServiceType : ETPCluster, ETPLocal
```
```
Type : PodToClusterIP, PodToLocalPod, PodToRemotePod, PodToNodePort, PodToIngressIP, ExternalToIngressIP, NodeToRemoteNode, PodToLocalNode, PodToInternet
```

#### Sample testconf.json file
```
{
    "ClusterInfo" : {
        "Name" : "aksAutTest",
        "RgName" : "pperRgTest",
        "SubscriptionId" : "0709bd7a-8383-4e1d-98c8-f81d1b3443fc",
        "NodePoolName" : "npwin",
        "OsSku" : "Windows2022",
        "NodeCount" : 2,
        "InstallRequired" : false,
        "UninstallAfterTest" : false,
        "ResetClusterCreds" : false,
        "Npm" : "",
        "Location" : "eastus2euap"
    },
    "AppInfo" : {
        "Namespace" : "demo",
        "ClientDeploymentName" : "tcp-client",
        "ServerDeploymentName" : "tcp-server",
        "ETPClusterServiceName" : "tcp-server-ipv4-cluster",
        "ETPLocalServiceName" : "tcp-server-ipv4-local",
        "ETPClusterServiceNameIPV6" : "tcp-server-ipv6-cluster",
        "ETPLocalServiceNameIPV6" : "tcp-server-ipv6-local",
        "ServiceCount" : 2,
        "ETPClusterServicePort" : "4444",
        "ETPLocalServicePort" : "4444",
        "ETPClusterServicePortIPV6" : "4444",
        "ETPLocalServicePortIPV6" : "4444",
        "InternalPort" : "4444",
        "InstallIPv4Required" : true,
        "InstallIPV6Required" : false,
        "UninstallAfterTest" : false,
        "LogPath" : ".\\logs\\TestcaseResults.log"
    },
    "SkipAllTestcases" : false,
    "SkipIPV4": false,
    "SkipIPV6": true,
    "Testcases" : [
        {
            "Name" : "[IPV4] Basic Pod to Service using Cluster IP",
            "Type" : "PodToClusterIP",
            "ServiceType" : "ETPCluster",
            "ServerPodCount" : 4,
            "ConnectionCount" : 2,
            "RequestsPerConnection" : 2,
            "TimeBtwEachRequestInMs" : 100,
            "Skip" : false
        },
        {
            "Name" : "[IPV6] Basic Pod to Internet",
            "Type" : "PodToInternet",
            "UseIPV6" : true
        }
    ]
}
```
