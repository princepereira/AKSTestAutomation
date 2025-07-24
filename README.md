# AKSTestAutomation
Automation framework for running AKS testcases.

## Configuration

The test framework is configured using the `testconf.json` file. This file contains all the necessary configuration for cluster setup, application deployment, and test execution.

## testconf.json Field Reference

### ClusterInfo Section

The `ClusterInfo` section contains configuration for the AKS cluster:

| Field | Type | Description | Required | Example |
|-------|------|-------------|----------|---------|
| `Name` | string | Name of the AKS cluster | Yes | `"pperAksNxgen"` |
| `RgName` | string | Resource group name for the cluster | Yes | `"pperRgNxgen"` |
| `SubscriptionId` | string | Azure subscription ID | Yes | `"[Provide SubscriptionId]"` |
| `ControlNodeOsSku` | string | OS SKU for control plane nodes | No | `"AzureLinux"` |
| `NodePoolName` | string | Name of the Windows node pool | Yes | `"npwin"` |
| `OsSku` | string | OS SKU for worker nodes | Yes | `"Windows2022"`, `"Windows2019"` |
| `NodeUsername` | string | Username for node access | Yes | `"azureuser"` |
| `NodePassword` | string | Password for node access | Yes | `"azureuser@123456"` |
| `NodeCount` | integer | Number of nodes in the cluster | Yes | `2` |
| `InstallRequired` | boolean | Whether cluster installation is required | Yes | `true` |
| `UninstallAfterTest` | boolean | Whether to uninstall cluster after tests | Yes | `false` |
| `ResetClusterCreds` | boolean | Whether to reset cluster credentials | Yes | `false` |
| `Npm` | string | Network Policy Manager (deprecated) | No | `""` |
| `Location` | string | Azure region for the cluster | Yes | `"centraluseuap"` |
| `NwPlugin` | string | Network plugin to use | Yes | `"azure"` |
| `NwPluginMode` | string | Network plugin mode | No | `"overlay"` or empty for single stack |
| `K8sVersion` | string | Kubernetes version | No | `""` (uses default) |
| `EnableRdp` | boolean | Enable RDP access to Windows nodes | No | `true` |
| `IsDualStack` | boolean | Enable dual-stack (IPv4/IPv6) networking | Yes | `true` |

### AppInfo Section

The `AppInfo` section contains configuration for test applications:

| Field | Type | Description | Required | Example |
|-------|------|-------------|----------|---------|
| `Namespace` | string | Kubernetes namespace for test apps | Yes | `"demo"` |
| `HpcDaemonsetName` | string | Name of the HPC daemonset | Yes | `"hpc-ds-win"` |
| `HpcNamespace` | string | Namespace for HPC components | Yes | `"demo"` |
| `ClientDeploymentName` | string | Name of the client deployment | Yes | `"tcp-client"` |
| `ServerDeploymentName` | string | Name of the server deployment | Yes | `"tcp-server"` |
| `ETPClusterServiceName` | string | IPv4 ETP cluster service name | Yes | `"tcp-server-ipv4-cluster"` |
| `ETPLocalServiceName` | string | IPv4 ETP local service name | Yes | `"tcp-server-ipv4-local"` |
| `ETPClusterServiceNameIPV6` | string | IPv6 ETP cluster service name | Yes | `"tcp-server-ipv6-cluster"` |
| `ETPLocalServiceNameIPV6` | string | IPv6 ETP local service name | Yes | `"tcp-server-ipv6-local"` |
| `ServiceCount` | integer | Number of services to create | Yes | `2` |
| `ETPClusterServicePort` | string | Port for IPv4 ETP cluster service | Yes | `"4444"` |
| `ETPLocalServicePort` | string | Port for IPv4 ETP local service | Yes | `"4444"` |
| `ETPClusterServicePortIPV6` | string | Port for IPv6 ETP cluster service | Yes | `"4444"` |
| `ETPLocalServicePortIPV6` | string | Port for IPv6 ETP local service | Yes | `"4444"` |
| `InternalPort` | string | Internal port for applications | Yes | `"4444"` |
| `InstallIPv4Required` | boolean | Whether to install IPv4 applications | Yes | `true` |
| `InstallIPV6Required` | boolean | Whether to install IPv6 applications | Yes | `true` |
| `UninstallAfterTest` | boolean | Whether to uninstall apps after tests | Yes | `false` |
| `LogPath` | string | Path for test result logs | Yes | `".\\logs\\TestcaseResults.log"` |

### Test Execution Control

Global test execution control flags:

| Field | Type | Description | Required | Example |
|-------|------|-------------|----------|---------|
| `SkipAllTestcases` | boolean | Skip all test execution | Yes | `true` |
| `SkipIPV4` | boolean | Skip IPv4 test cases | Yes | `false` |
| `SkipIPV6` | boolean | Skip IPv6 test cases | Yes | `true` |

### Test Case Configuration

Test cases are defined in `IPV4Testcases` and `IPV6Testcases` arrays. Each test case has the following structure:

#### Common Test Case Fields

| Field | Type | Description | Required | Example |
|-------|------|-------------|----------|---------|
| `Name` | string | Descriptive name for the test case | Yes | `"Basic Pod to Local Pod using Pod IP"` |
| `Type` | string | Type of test to execute (see supported types below) | Yes | `"PodToLocalPod"` |
| `Skip` | boolean | Whether to skip this test case | Yes | `false` |

#### Network Test Fields

For network connectivity tests:

| Field | Type | Description | Required | Test Types |
|-------|------|-------------|----------|------------|
| `ConnectionCount` | integer | Number of concurrent connections | No | TCP tests |
| `RequestsPerConnection` | integer | Requests per connection | No | TCP tests |
| `TimeBtwEachRequestInMs` | integer | Delay between requests (ms) | No | TCP tests |
| `RemoteAddress` | string | Target address for internet tests | No | Internet tests |
| `DnsName` | string | DNS name for service resolution | No | Service tests |

#### Service Test Fields

For service-related tests:

| Field | Type | Description | Required | Test Types |
|-------|------|-------------|----------|------------|
| `ServiceType` | string | Service type: `"ETPCluster"` or `"ETPLocal"` | No | Service tests |
| `ServerPodCount` | integer | Number of server pods to deploy | No | Service tests |

#### Advanced Test Fields

For advanced test scenarios:

| Field | Type | Description | Required | Test Types |
|-------|------|-------------|----------|------------|
| `Actions` | array | Sequence of actions to perform during test | No | Complex tests |
| `ExpectedResult` | string | Expected test outcome | No | Complex tests |

#### Supported Test Types

**Pod-to-Pod Communication:**
- `PodToLocalPod` - Pod to pod on same node
- `PodToRemotePod` - Pod to pod on different node

**Pod-to-Service Communication:**
- `PodToClusterIP` - Pod to service using cluster IP
- `PodToNodePort` - Pod to service using node port
- `PodToIngressIP` - Pod to service using ingress IP

**Node Communication:**
- `NodeToLocalPod` - Node to pod on same node
- `NodeToRemotePod` - Node to pod on different node
- `NodeToClusterIP` - Node to service using cluster IP

**External Communication:**
- `ExternalToIngressIP` - External client to service
- `PodToInternet` - Pod to internet connectivity

**Ping Tests:**
- `PingPodToLocalNode` - Ping from pod to local node
- `PingPodToRemoteNode` - Ping from pod to remote node
- `PingPodToInternet` - Ping from pod to internet
- `PingNodeToRemoteNode` - Ping between nodes
- `PingNodeToRemotePod` - Ping from node to remote pod
- `PingNodeToLocalPod` - Ping from node to local pod  
- `PingNodeToInternet` - Ping from node to internet

**Advanced Tests:**
- `ProxyTerminatingLinuxNodeToPod` - Proxy terminating endpoint tests
- `ProxyTerminatingWinNodeToLocalPod` - Windows node proxy tests
- `ProxyTerminatingWinNodeToRemotePod` - Windows node remote proxy tests

#### Actions Array

The `Actions` array allows defining complex test scenarios with sequential actions:

| Action | Description | Parameters |
|--------|-------------|------------|
| `StartTcpClient` | Start TCP client connections | `true` |
| `ScaleTo` | Scale deployment to specified replica count | `<number>` |
| `Sleep` | Wait for specified seconds | `<seconds>` |
| `FailReadinessProbe` | Make readiness probe fail | `true` |
| `PassReadinessProbe` | Make readiness probe pass | `true` |
| `Seq` | Sequence number for action ordering | `<number>` |

Actions are only supported for: `PodToClusterIP`, `PodToIngressIP`, `ExternalToIngressIP`

## How to run test framework

```
Modify testconf.json

Run testcases

PS> .\starttest.ps1

```

## Sample testconf.json Configuration

Here's a complete example configuration file:

```json
{
    "ClusterInfo" : {
        "Name" : "aksAutTest",
        "RgName" : "pperRgTest",
        "SubscriptionId" : "0709bd7a-8383-4e1d-98c8-f81d1b3443fc",
        "ControlNodeOsSku" : "AzureLinux",
        "NodePoolName" : "npwin",
        "OsSku" : "Windows2022",
        "NodeUsername" : "azureuser",
        "NodePassword" : "azureuser@123456",
        "NodeCount" : 2,
        "InstallRequired" : false,
        "UninstallAfterTest" : false,
        "ResetClusterCreds" : false,
        "Npm" : "",
        "Location" : "eastus2euap",
        "NwPlugin" : "azure",
        "NwPluginMode" : "overlay",
        "K8sVersion" : "",
        "EnableRdp" : true,
        "IsDualStack" : true
    },
    "AppInfo" : {
        "Namespace" : "demo",
        "HpcDaemonsetName" : "hpc-ds-win",
        "HpcNamespace" : "demo",
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
    "IPV4Testcases" : [
        {
            "Name" : "Basic Pod to Service using Cluster IP",
            "Type" : "PodToClusterIP",
            "ServiceType" : "ETPCluster",
            "ServerPodCount" : 4,
            "ConnectionCount" : 2,
            "RequestsPerConnection" : 2,
            "TimeBtwEachRequestInMs" : 100,
            "Skip" : false
        },
        {
            "Name" : "Advanced Pod to Service with Actions",
            "Type" : "PodToClusterIP",
            "ServiceType" : "ETPCluster",
            "ServerPodCount" : 4,
            "ConnectionCount" : 2,
            "RequestsPerConnection" : 2,
            "TimeBtwEachRequestInMs" : 100,
            "Actions" : [
                { "StartTcpClient" : true, "Sleep" : 2, "Seq" : 1 },
                { "ScaleTo" : 2, "Sleep" : 2, "Seq" : 2 },
                { "FailReadinessProbe" : false, "Seq" : 3 },
                { "ScaleTo" : 4, "Sleep" : 4, "Seq" : 4 },
                { "PassReadinessProbe" : true, "Seq" : 5 }
            ],
            "ExpectedResult" : "ConnectionsSucceded:2, ConnectionsFailed:0",
            "Skip" : false
        },
        {
            "Name" : "Basic Ping Pod to Remote Node",
            "Type" : "PingPodToRemoteNode",
            "Skip" : false
        },
        {
            "Name" : "Basic Ping Pod to Internet",
            "Type" : "PingPodToInternet",
            "RemoteAddress" : "bing.com", 
            "Skip" : false
        }
    ],
    "IPV6Testcases" : [
        {
            "Name" : "IPv6 Pod to Internet",
            "Type" : "PodToInternet",
            "RemoteAddress" : "bing.com",
            "Skip" : false
        }
    ]
}
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
            "Name" : "[IPV4] Basic Pod to Service using Cluster IP",
            "Type" : "PodToClusterIP",
            "ServiceType" : "ETPCluster",
            "ServerPodCount" : 4,
            "ConnectionCount" : 2,
            "RequestsPerConnection" : 2,
            "TimeBtwEachRequestInMs" : 100,
            "Actions" : [
                { "StartTcpClient" : true },
                { "ScaleTo" : 2 },
                { "FailReadinessProbe" : false },
                { "ScaleTo" : 4 },
                { "Sleep" : 4 },
                { "PassReadinessProbe" : true }
            ],
            "ExpectedResult" : "ConnectionsSucceded:2, ConnectionsFailed:0",
            "Skip" : false
        },
        {
            "Name" : "[IPV4] Basic Ping Pod to Remote Node using Node IP",
            "Type" : "PingPodToRemoteNode",
            "Skip" : false
        },
        {
            "Name" : "[IPV4] Basic Ping Pod to Internet using bing.com",
            "Type" : "PingPodToInternet",
            "RemoteAddress" : "abc.com", 
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
