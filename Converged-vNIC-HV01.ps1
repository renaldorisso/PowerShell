#Script para criar as interfaces virtuais para o cluster de windows server 
#

# Cria um time de rede usando todas as interfaces de rede disponivel no servidor com as opções TeamingMode LACP e portMode Hyper-V 
New-NetLbfoTeam "TEAM-vNIC" –TeamMembers * –TeamNicName "TEAM-vNIC" -TeamingMode Lacp -LoadBalancingAlgorithm HyperVPort

# Cria um switch virtual 
New-VMSwitch “TEAM-vSW” -MinimumBandwidthMode Weight -NetAdapterName “TEAM-vNIC” -AllowManagementOS 0
Set-VMSwitch “TEAM-vSW” -DefaultFlowMinimumBandwidthWeight 0

# Cria uma placa de rede virtual chamada MGMT-vNIC
Add-VMNetworkAdapter -ManagementOS -Name “MGMT-vNIC” -SwitchName “TEAM-vSW”
Set-VMNetworkAdapter -ManagementOS -Name “MGMT-vNIC” -VmqWeight 80 -MinimumBandwidthWeight 10

# Cria uma placa de rede virtual chamada Cluster-vNIC
Add-VMNetworkAdapter -ManagementOS -Name “Cluster-vNIC” -SwitchName “TEAM-vSW”
Set-VMNetworkAdapter -ManagementOS -Name “Cluster-vNIC” -VmqWeight 80 -MinimumBandwidthWeight 10

# Cria uma placa de rede virtual chamada LM-vNIC
Add-VMNetworkAdapter -ManagementOS -Name “LM-vNIC” -SwitchName “TEAM-vSW”
Set-VMNetworkAdapter -ManagementOS -Name “LM-vNIC” -VmqWeight 90 -MinimumBandwidthWeight 40

# Cria uma placa de rede virtual chamada iSCSI-vNIC
Add-VMNetworkAdapter -ManagementOS -Name “iSCSI-vNIC” -SwitchName “TEAM-vSW”
Set-VMNetworkAdapter -ManagementOS -Name “iSCSI-vNIC” -VmqWeight 100 -MinimumBandwidthWeight 40

write-host “Aguarde 30 segundos para iniciar os adaptadores”
Start-Sleep -s 30

write-host “Configurando os IPs das placas virtuais”
New-NetIPAddress -InterfaceAlias “vEthernet (MGMT-vNIC)” -IPAddress 192.168.0.21 -PrefixLength 21 -DefaultGateway 192.168.3.2
Set-DnsClientServerAddress -InterfaceAlias “vEthernet (MGMT-vNIC)” -ServerAddresses “192.168.3.45”

New-NetIPAddress -InterfaceAlias “vEthernet (Cluster-vNIC)” -IPAddress 10.250.200.1 -PrefixLength “24”

New-NetIPAddress -InterfaceAlias “vEthernet (LM-vNIC)” -IPAddress 10.250.201.1 -PrefixLength “24”

New-NetIPAddress -InterfaceAlias “vEthernet (iSCSI-vNIC)” -IPAddress 172.16.32.11 -PrefixLength “24”


#Prioridade na placa de Cluster
#(Get-ClusterNetwork Cluster-vNIC).Metric = 900

