$ZipPath = "Binaries.zip"
$DirPath = "Binaries"

$CreateZip = $true
$CopyBinaries = $true
$KeepOriginal = $false # This will replace the selected binaries with original binaries
$EnableTestSigning = $true
$ReplaceHns = $true
$ReplaceVfpCtrl = $false
$ReplaceVfpExt = $false
$ReplaceVfpApi = $false
$ReplaceKubeProxy = $false
$ReplaceAzureVnet = $false
$ReplaceIpHelperApiDll = $true
$ReplaceMpsSvcDll = $true
$ReplaceNetVscSys = $true
$ReplaceTcpIpSys = $true
$ReplaceNetioSys = $true
$SetRegKeys = $false
$RunPSScript = $false
$CopyFile = $false


$HpcName = "hpc-ds-win"
$WinVersion = "2022" # 2022 / 2019
$Namespace = "demo"

$RegKeys = @(
    # "Set-ItemProperty -Path HKLM:\\SYSTEM\\CurrentControlSet\\Services\\hns\\State -Name SDNIpv6DefaultGw -Value 'fe80::1234:5678:9abc'"
    "Set-ItemProperty -Path HKLM:\\SYSTEM\\CurrentControlSet\\Services\\hns\\State -Name SdnGatewayArpMac -Value '12-34-56-78-9a-bc'"
)

$ScriptName = "removeArp.ps1"
$ScriptNodeDstPath = "C:\k"
$ScriptCmd = "C:\k\removeArp.ps1"

$FileName = "TTD.zip"
$FileDstPath = "C:\k"

function ValidateHPC {
    $result = kubectl get daemonset hpc-ds-win -n demo
    if($null -ne $result) {
        return $true
    }
    kubectl create namespace demo

    if($WinVersion -eq "2022") {
        kubectl create -f .\Yamls\HPC\hpc-ds-win22.yaml
    } else {
        kubectl create -f .\Yamls\HPC\hpc-ds-win19.yaml
    }
    
    Start-Sleep -Seconds 5
    $result = kubectl get daemonset hpc-ds-win -n demo -o json | ConvertFrom-Json
    if($result.status.desiredNumberScheduled -eq 0) {
        Write-Host "HPC daemonset cannot be brought up. Desired pods are zero." -ForegroundColor Red
        kubectl delete -f .\Yamls\HPC\
        return $false
    }
    $count = 0
    While($true) {
        $result = kubectl get daemonset hpc-ds-win -n demo -o json | ConvertFrom-Json
        $status = $result.status
        if($status.desiredNumberScheduled -eq $status.numberReady) {
            Start-Sleep -Seconds 5
            return $true
        }
        Write-Host "Waiting for HPC pods to be ready..."
        $count += 1
        if($coun -gt 48) {
            Write-Host "HPC daemonset cannot be brought up. Took more time." -ForegroundColor Red
            kubectl delete -f .\Yamls\HPC
            return $false
        }
        Start-Sleep -Seconds 5
    }
    return $true
}

function GetAllPodNames {
    param (
        [Parameter (Mandatory = $true)] [String]$namespace,
        [Parameter (Mandatory = $true)] [String]$daemonsetName
    )
    $podNames = @()
    $metadatas = ((kubectl get pods -n $namespace -o json | ConvertFrom-Json).Items).metadata
    foreach($metadata in $metadatas) { 
        if(($metadata.labels).Name -eq $daemonsetName ) { 
            $podNames += $metadata.name 
        } 
    }
    return $podNames
}

function ValidateBinariesDir {

    if((Test-Path $DirPath) -eq $false) {
        Write-Host "Missing dir [$DirPath] "
        return $false
    }

    $missingBins = @()
    $sfpcopyNeeded = $false

    if($ReplaceHns -and ((Test-Path $DirPath\hostnetsvc.dll) -eq $false)) {
        $missingBins += "hostnetsvc.dll"
    }

    if($ReplaceVfpCtrl -and ((Test-Path $DirPath\vfpctrl.exe) -eq $false)){
        $missingBins += "vfpctrl.exe"
    }

    if($ReplaceVfpExt -and ((Test-Path $DirPath\vfpext.sys) -eq $false)) {
        $missingBins += "vfpext.sys"
    }

    if($ReplaceVfpApi -and ((Test-Path $DirPath\vfpapi.dll) -eq $false)){
        $missingBins += "vfpapi.dll"
    }

    if($ReplaceTcpIpSys -and ((Test-Path $DirPath\tcpip.sys) -eq $false)) {
        $missingBins += "tcpip.sys"
    }

    if($ReplaceIpHelperApiDll  -and ((Test-Path $DirPath\iphlpapi.dll) -eq $false)) {
        $missingBins += "iphlpapi.dll"
    }

    if($ReplaceMpsSvcDll  -and ((Test-Path $DirPath\MPSSVC.dll) -eq $false)) {
        $missingBins += "MPSSVC.dll"
    }

    if($ReplaceNetVscSys -and ((Test-Path $DirPath\netvsc.sys) -eq $false)) {
        $missingBins += "netvsc.sys"
    }

    if($ReplaceNetioSys -and ((Test-Path $DirPath\netio.sys) -eq $false)) {
        $missingBins += "netio.sys"
    }

    if($ReplaceKubeProxy -and ((Test-Path $DirPath\kube-proxy.exe) -eq $false)) {
        $missingBins += "kube-proxy.exe"
    }

    if($ReplaceAzureVnet -and ((Test-Path $DirPath\azure-vnet.exe) -eq $false)){
        $missingBins += "azure-vnet.exe"
    }

    if($ReplaceHns -or $ReplaceVfpCtrl -or $ReplaceVfpExt -or $ReplaceVfpApi -or $ReplaceKubeProxy -or $ReplaceTcpIpSys -or $ReplaceNetioSys -or $ReplaceNetVscSys) {
        $sfpcopyNeeded = $true
    }

    if($sfpcopyNeeded -and ((Test-Path $DirPath\sfpcopy.exe) -eq $false)) {
        $missingBins += "sfpcopy.exe"
    }

    if($missingBins.Count -gt 0) {
        Write-Host "Missing binaries in dir [$DirPath] : $missingBins"
        return $false
    }

    if($RunPSScript -and ((Test-Path $DirPath\$ScriptName) -eq $false)) {
        Write-Host "Missing Powershell script: $DirPath\$ScriptName"
        return $false
    }

    if($CopyFile -and ((Test-Path $DirPath\$FileName) -eq $false)) {
        Write-Host "Missing file to copy: $DirPath\$FileName"
        return $false
    }

    return $true
}

if($CreateZip) {
    if(!(ValidateBinariesDir)) {
        return
    }
    Write-Host "Creating Binary zip."
    Remove-Item -Recurse -Force $ZipPath -ErrorAction Ignore
    Compress-Archive -Path $DirPath -DestinationPath $ZipPath
}

$hpcResult = ValidateHPC
if($false -eq $hpcResult) {
    return
}

if($EnableTestSigning) {
    $allHpcPods = GetAllPodNames -namespace $Namespace -daemonsetName $HpcName
    foreach($hpcPod in $allHpcPods) {
        Write-Host "Enabling test signing on : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command SET NT_SIGNCODE=1
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command bcdedit.exe /set testsigning ON
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command bcdedit.exe /debug off
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command bcdedit.exe /bootdebug off
        Write-Host "Restarting the node : $hpcPod initiated in 3 seconds."
        Start-Sleep -Seconds 2
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Restart-Computer -Force
    }
    $now = Get-date
    Write-Host "Waiting for 3 minutes for nodes to be up. Current time is $now."
    Start-Sleep -Seconds 180
}

$allHpcPods = GetAllPodNames -namespace $Namespace -daemonsetName $HpcName
foreach($hpcPod in $allHpcPods) {

    Write-Host "Setting up host pod : $hpcPod"
    if($CopyBinaries) {
        Write-Host "Cleaning up existing binaries : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command rm -r -Force $ZipPath -ErrorAction Ignore
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command rm -r -Force Binaries -ErrorAction Ignore
        Write-Host "Copying binaries to : $hpcPod"
        kubectl cp .\$ZipPath $hpcPod`:$ZipPath -n $Namespace
        Start-Sleep -Seconds 1
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Expand-Archive -Path $ZipPath -DestinationPath .
    }
    
    # Taking Backup of originals
    $origDirExists = kubectl exec $hpcPod -n $Namespace -- powershell -command Test-Path C:\k\orig
    if($origDirExists -eq $false) {
        Write-Host "Taking backup of original binaries : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command mkdir C:\k\orig
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command cp Binaries\sfpcopy.exe C:\k\orig\
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command cp C:\k\azure-vnet.json C:\k\orig\
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command cp C:\k\azurecni\netconf\10-azure.conflist C:\k\orig\
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command cp C:\Windows\system32\vfpctrl.exe C:\k\orig\
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command cp C:\Windows\system32\hostnetsvc.dll C:\k\orig\
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command cp C:\k\azurecni\bin\azure-vnet.exe C:\k\orig\
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command cp C:\Windows\system32\drivers\vfpext.sys C:\k\orig\
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command cp C:\Windows\system32\drivers\tcpip.sys C:\k\orig\
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command cp C:\Windows\system32\drivers\netio.sys C:\k\orig\
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command cp C:\Windows\system32\vfpapi.dll C:\k\orig\
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command cp C:\k\kube-proxy.exe C:\k\orig\
    }

    if($SetRegKeys) {
        Write-Host "Setting up host pod reg keys : $hpcPod"
        foreach($key in $RegKeys) {
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command $key
        }
        Write-Host "Reg keys set : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command reg query HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\hns\State
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command reg query HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\VfpExt\Parameters
    }

    $restartNode = $false

    if($ReplaceAzureVnet) {
        if($KeepOriginal) {
            Write-Host "Replacing with original azure vnet in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command cp C:\k\orig\azure-vnet.exe C:\k\azurecni\bin\azure-vnet.exe
        } else {
            Write-Host "Replacing with custom azure vnet in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command cp .\Binaries\azure-vnet.exe C:\k\azurecni\bin\azure-vnet.exe
        }
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command rm C:\k\azure-vnet.json -ErrorAction Ignore
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command "Get-HnsNetwork | Where name -eq azure | Remove-HnsNetwork"
        Write-Host "FileHash for azure vnet : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Get-FileHash C:\k\azurecni\bin\azure-vnet.exe
    }

    if($ReplaceHns) {
        if($KeepOriginal) {
            Write-Host "Replacing with original hns in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command C:\k\orig\sfpcopy.exe C:\k\orig\HostNetSvc.dll C:\Windows\system32\hostnetsvc.dll
        } else {
            Write-Host "Replacing with custom hns in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command .\Binaries\sfpcopy.exe .\Binaries\HostNetSvc.dll C:\Windows\system32\hostnetsvc.dll
        }
        Start-Sleep -Seconds 3
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Restart-Service -f hns
        Start-Sleep -Seconds 2
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Get-Service hns
        Write-Host "FileHash for hns : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Get-FileHash C:\Windows\system32\hostnetsvc.dll
    }
    
    if($ReplaceIpHelperApiDll) {
        $restartNode = $true
        if($KeepOriginal) {
            Write-Host "Replacing with original IP Helper Dll in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command C:\k\orig\sfpcopy.exe C:\k\orig\iphlpapi.dll C:\Windows\system32\iphlpapi.dll
        } else {
            Write-Host "Replacing with custom IP Helper Dll in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command .\Binaries\sfpcopy.exe .\Binaries\iphlpapi.dll C:\Windows\system32\iphlpapi.dll
        }
        Start-Sleep -Seconds 3
        Write-Host "FileHash for iphlpapi : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Get-FileHash C:\Windows\system32\iphlpapi.dll
    }

    if($ReplaceMpsSvcDll ) {
        $restartNode = $true
        if($KeepOriginal) {
            Write-Host "Replacing with original MPSSVC Dll in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command C:\k\orig\sfpcopy.exe C:\k\orig\MPSSVC.dll C:\Windows\system32\MPSSVC.dll
        } else {
            Write-Host "Replacing with custom MPSSVC Dll in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command .\Binaries\sfpcopy.exe .\Binaries\MPSSVC.dll C:\Windows\system32\MPSSVC.dll
        }
        Start-Sleep -Seconds 3
        Write-Host "FileHash for MPSSVC : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Get-FileHash C:\Windows\system32\MPSSVC.dll
    }

    if($ReplaceVfpExt) {
        $restartNode = $true
        if($KeepOriginal) {
            Write-Host "Replacing with original vfpext.sys in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command C:\k\orig\sfpcopy.exe C:\k\orig\vfpext.sys C:\Windows\system32\drivers\vfpext.sys
        } else {
            Write-Host "Replacing with custom vfpext.sys in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command .\Binaries\sfpcopy.exe .\Binaries\vfpext.sys C:\Windows\system32\drivers\vfpext.sys
        }
        Start-Sleep -Seconds 2
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Restart-Service -f vfpext
        Start-Sleep -Seconds 2
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Get-Service vfpext
        Write-Host "FileHash for vfpext.sys : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Get-FileHash C:\Windows\system32\drivers\vfpext.sys
    }

    if($ReplaceTcpIpSys) {
        $restartNode = $true
        if($KeepOriginal) {
            Write-Host "Replacing with original tcpip.sys in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command C:\k\orig\sfpcopy.exe C:\k\orig\tcpip.sys C:\Windows\system32\drivers\tcpip.sys
        } else {
            Write-Host "Replacing with custom tcpip.sys in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command .\Binaries\sfpcopy.exe .\Binaries\tcpip.sys C:\Windows\system32\drivers\tcpip.sys
        }
        Start-Sleep -Seconds 3
        Write-Host "FileHash for tcpip.sys : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Get-FileHash C:\Windows\system32\drivers\tcpip.sys
    }

    if($ReplaceNetioSys) {
        $restartNode = $true
        if($KeepOriginal) {
            Write-Host "Replacing with original netio.sys in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command C:\k\orig\sfpcopy.exe C:\k\orig\netio.sys C:\Windows\system32\drivers\netio.sys
        } else {
            Write-Host "Replacing with custom netio.sys in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command .\Binaries\sfpcopy.exe .\Binaries\netio.sys C:\Windows\system32\drivers\netio.sys
        }
        Start-Sleep -Seconds 3
        Write-Host "FileHash for netio.sys : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Get-FileHash C:\Windows\system32\drivers\netio.sys
    }

    if($ReplaceNetVscSys ) {
        $restartNode = $true
        if($KeepOriginal) {
            Write-Host "Replacing with original netvsc.sys in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command C:\k\orig\sfpcopy.exe C:\k\orig\netvsc.sys C:\Windows\system32\drivers\netvsc.sys
        } else {
            Write-Host "Replacing with custom netvsc.sys in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command .\Binaries\sfpcopy.exe .\Binaries\netvsc.sys C:\Windows\system32\drivers\netvsc.sys
        }
        Start-Sleep -Seconds 3
        Write-Host "FileHash for netvsc.sys : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Get-FileHash C:\Windows\system32\drivers\netvsc.sys
    }

    if($ReplaceVfpApi) {
        if($KeepOriginal) {
            Write-Host "Replacing with original vfpapi.dll in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command C:\k\orig\sfpcopy.exe C:\k\orig\vfpapi.dll C:\Windows\system32\vfpapi.dll
        } else {
            Write-Host "Replacing with custom vfpapi.dll in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command .\Binaries\sfpcopy.exe .\Binaries\vfpapi.dll C:\Windows\system32\vfpapi.dll
        }
        Write-Host "FileHash for vfpapi.dll : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Get-FileHash C:\Windows\system32\vfpapi.dll
    }

    if($ReplaceVfpCtrl) {
        if($KeepOriginal) {
            Write-Host "Replacing with original vfpctrl in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command C:\k\orig\sfpcopy.exe C:\k\orig\vfpctrl.exe C:\Windows\system32\vfpctrl.exe
        } else {
            Write-Host "Replacing with custom vfpctrl in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command .\Binaries\sfpcopy.exe .\Binaries\vfpctrl.exe C:\Windows\system32\vfpctrl.exe
        }
        Write-Host "FileHash for vfpctrl : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Get-FileHash C:\Windows\system32\vfpctrl.exe
    }

    if($ReplaceKubeProxy) {
        if($KeepOriginal) {
            Write-Host "Replacing with original KubeProxy in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command C:\k\orig\sfpcopy.exe C:\k\orig\kube-proxy.exe C:\k\kube-proxy.exe
        } else {
            Write-Host "Replacing with custom KubeProxy in : $hpcPod"
            kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command .\Binaries\sfpcopy.exe .\Binaries\kube-proxy.exe C:\k\kube-proxy.exe
        }
        Start-Sleep -Seconds 2
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Restart-Service -f kubeproxy
        Start-Sleep -Seconds 2
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Get-Service kubeproxy
        Write-Host "FileHash for KubeProxy : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Get-FileHash C:\k\kube-proxy.exe
    }

    if($restartNode) {
        Write-Host "Restarting the node : $hpcPod initiated in 3 seconds."
        Start-Sleep -Seconds 3
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command Restart-Computer -Force
    }

    Write-Host "Setting up host pod : $hpcPod completed"

    if($RunPSScript) {
        Write-Host "Running powershell script $ScriptName in : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command cp .\Binaries\$ScriptName $ScriptNodeDstPath\$ScriptName
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted "Start-Job -FilePath $ScriptCmd"
        Write-Host "Running powershell script $ScriptName in : $hpcPod completed."
    }

    if($CopyFile) {
        Write-Host "Copying file $FileName in : $hpcPod"
        kubectl exec $hpcPod -n $Namespace -- powershell -ExecutionPolicy Unrestricted -command cp .\Binaries\$FileName $FileDstPath\$FileName
        Write-Host "Copying file $FileName in : $hpcPod completed."
    }

}
