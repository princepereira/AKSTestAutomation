rm -r -Force kubeproxy -ErrorAction SilentlyContinue
Expand-Archive kubeproxy.zip -DestinationPath kubeproxy -Force
if (-not (Test-Path -Path C:\k\kube-proxy.exe)) {
    Copy-Item -Path C:\k\kube-proxy.exe -Destination C:\k\kube-proxy_Orig.exe -Force
}
.\sfpcopy.exe .\kubeproxy\kube-proxy.exe C:\k\kube-proxy.exe
Stop-Service -Force KubeProxy
Start-Sleep -Seconds 1
rm C:\k\kubeproxy.err.log -ErrorAction SilentlyContinue
Restart-Computer -Force

