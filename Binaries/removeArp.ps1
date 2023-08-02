$iteration = 0
$scriptLogs = "scriptLogs.log"
while ($true) {
    Start-Sleep -Seconds 3
    $iteration += 1
    Write-Host "Removing router gw arp Entry..."
    Remove-NetNeighbor -IPAddress fe80::1234:5678:9abc -LinkLayerAddress 12-34-56-78-9A-BC -InterfaceAlias 'vEthernet (Ethernet 2)' -PolicyStore ActiveStore -Confirm:$false
    Start-Sleep -Seconds 1
    Write-Host "Ping router gw..."
    ping -6 fe80::1234:5678:9abc -n 1
    route print -6 > $scriptLogs
}