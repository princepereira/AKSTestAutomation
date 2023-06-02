Keep the Windows binaries to be replaced here. Also keep sfpcopy.exe. Then enable the required flags in replacebinaries.ps1

If hpc pods are not running, please run using command
```
kubectl create namespace demo
kubectl create -f Yamls\HPC\.
.\replacebinaries.ps1
```