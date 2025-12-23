mkdir logs -ErrorAction SilentlyContinue
cd logs
Rm -r -force * -ErrorAction SilentlyContinue
cp C:\k\kubeproxy.err.log .
cp C:\k\azure-vnet.log .
Get-HnsNetwork | ConvertTo-Json -Depth 10 > network.txt
Get-HnsPolicyList | ConvertTo-Json -Depth 10 > policy.txt
Get-HnsEndpoint | ConvertTo-Json -Depth 10 > endpoint.txt
$ports = (vfpctrl.exe /list-vmswitch-port /format 1 | ConvertFrom-Json).Ports.Name
foreach ($port in $ports) {
	Write-Output "Dumping vfp rules for Port: $port" > vfprules.txt
	vfpctrl /port $port /list-rule >> .\vfprules.txt
}
cd ..
rm logs.zip -ErrorAction SilentlyContinue
Compress-archive logs\* logs.zip