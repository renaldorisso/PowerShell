<# 
    Description:
    This script can be used as a template for deploying Hyper-V Converged networking.
    With Windows Server 2012 and above you can combine your 10 GbE (or 1 GbE) NIC's 
    and utilize the bandwidth of all of your network adapters for management, cluster, 
    live migration.
       
    Due to the network changes made in this script it is best to copy this script to the server
    and run it from the server.
#> 
param (
    $TeamName = 'TEAM-vNIC',
    $SwitchName = 'TEAM-vSW',
    $DefaultFlowMinimumBandwidthWeight = 50,
    
    $ManagementNetAdapterName = 'MGMT',
    $ManagementNetAdapterVlan = 1,
    $ManagementNetAdapterIp = '192.168.0.210',
    $ManagementNetAdapterPrefix = 21,
    $ManagementNetAdapterGateway = '192.168.3.2',
    $ManagementNetAdapterDnsServers = '192.168.3.45,192.168.3.44',
    $ManagementNetAdapterWeight = 20,

    $ClusterNetAdapterName = 'Cluster',
    $ClusterNetAdapterVlan = 200,
    $ClusterNetAdapterIp = '10.250.200.6',
    $ClusterNetAdapterPrefix = 28,
    $ClusterNetAdapterWeight = 10,

    $LiveMigrationNetAdapterName = 'LM',
    $LiveMigrationNetAdapterVlan = 201,
    $LiveMigrationNetAdapterIp = '10.250.201.6',
    $LiveMigrationNetAdapterPrefix = 28,
    $LiveMigrationNetAdapterWeight = 20
        
    )

# Change these IP addresses and netmask to parameters.

### Rename Physical Adapters First
# Rename-NetAdapter "LAN 1" -NewName "10GBE1"
# Rename-NetAdapter "LAN 2" -NewName "10GBE2"

### Disable Unused NIC Adapters
# Disable-NetAdapter -Name "LAN 4"

# May need to remove any existing switch, and vm network adapters first.

### Delete existing VMNetworkAdapters from the management OS
# Get-VMNetworkAdapter -ManagementOS | Remove-VMNetworkAdapter

### Delete existing VM Switches
# Get-VMSwitch | Remove-VMSwitch

### Remove Existing Team
# Get-NetLbfoTeam | Remove-NetLbfoTeam

# Disable VMQ in interface
Get-NetAdapterVmq | foreach { Set-NetAdapterVmq -Name $_.Name -Enabled $False }

### Creating Team from two 10 GbE adapters. The adapter names should be specified as 10GbE1 or whatever name is desired.
New-NetLBFOTeam –Name $TeamName –TeamMembers "NIC2","NIC3","NIC4","NIC5","NIC6" –TeamingMode Lacp –LoadBalancingAlgorithm Dynamic

############ Create Hyper-V Switches for converged networking using weight based QoS.  ##############

# Creating Hyper-V Switch for Management, cluster, Live migration and VM converged networks.
# The switch uses weight bandwidth mode for QoS
# Bandwidth weight should total 100
# Management     20
# Cluster        10
# Live Migration 20
# Default(VM)    50

# Assuming all networks will go through this team.
New-VMSwitch $SwitchName –NetAdapterName $TeamName –AllowManagementOS 0 –MinimumBandwidthMode Weight -Notes "Management, Cluster, LiveMigration and VM networks."

# Set default QoS bucket which will be used by VM traffic
Set-VMSwitch $SwitchName –DefaultFlowMinimumBandwidthWeight $DefaultFlowMinimumBandwidthWeight

######################################################################################################

# Create and configure Management network
Add-VMNetworkAdapter -ManagementOS -Name $ManagementNetAdapterName -SwitchName $SwitchName
Set-VMNetworkAdapter -ManagementOS -Name $ManagementNetAdapterName -MinimumBandwidthWeight $ManagementNetAdapterWeight
New-NetIPAddress -InterfaceAlias "vEthernet ($ManagementNetAdapterName)" -IPAddress $ManagementNetAdapterIp -PrefixLength $ManagementNetAdapterPrefix -DefaultGateway $ManagementNetAdapterGateway
Set-DnsClientServerAddress -InterfaceAlias "vEthernet ($ManagementNetAdapterName)" -ServerAddresses $ManagementNetAdapterDnsServers
#Get-VMNetworkAdapter -ManagementOS $ManagementNetAdapterName | Set-VMNetworkAdapterVlan -Access -VlanId $ManagementNetAdapterVlan
Get-NetAdapter -Name "vEthernet ($ManagementNetAdapterName)" | Get-NetAdapterAdvancedProperty -DisplayName "Jumbo Packet" | Set-NetAdapterAdvancedProperty -RegistryValue 9014

# Create and configure the Cluster network
Add-VMNetworkAdapter -ManagementOS -Name $ClusterNetAdapterName -SwitchName $SwitchName
Set-VMNetworkAdapter -ManagementOS -Name $ClusterNetAdapterName -MinimumBandwidthWeight $ClusterNetAdapterWeight
New-NetIPAddress -InterfaceAlias "vEthernet ($ClusterNetAdapterName)" -IPAddress $ClusterNetAdapterIp -PrefixLength $ClusterNetAdapterPrefix
#Get-VMNetworkAdapter -ManagementOS $ClusterNetAdapterName | Set-VMNetworkAdapterVlan -Access -VlanId $ClusterNetAdapterVlan
Get-NetAdapter -Name "vEthernet ($ClusterNetAdapterName)" | Get-NetAdapterAdvancedProperty -DisplayName "Jumbo Packet" | Set-NetAdapterAdvancedProperty -RegistryValue 9014

# Create and configure the Live Migration network
Add-VMNetworkAdapter -ManagementOS -Name $LiveMigrationNetAdapterName -SwitchName $SwitchName
Set-VMNetworkAdapter -ManagementOS -Name $LiveMigrationNetAdapterName -MinimumBandwidthWeight $LiveMigrationNetAdapterWeight
New-NetIPAddress -InterfaceAlias "vEthernet ($LiveMigrationNetAdapterName)" -IPAddress $LiveMigrationNetAdapterIp -PrefixLength $LiveMigrationNetAdapterPrefix
#Get-VMNetworkAdapter -ManagementOS $LiveMigrationNetAdapterName | Set-VMNetworkAdapterVlan -Access -VlanId $LiveMigrationNetAdapterVlan
Get-NetAdapter -Name "vEthernet ($LiveMigrationNetAdapterName)" | Get-NetAdapterAdvancedProperty -DisplayName "Jumbo Packet" | Set-NetAdapterAdvancedProperty -RegistryValue 9014

# Disale IPV6 in all interfaces
Get-NetAdapter | foreach { Disable-NetAdapterBinding -InterfaceAlias $_.Name -ComponentID ms_tcpip6 }

# Verify Bandwidth percentage for the newly created NIC's and SW
Get-VMNetworkAdapter -ManagementOS | Select-Object -Property Name,BandwidthPercentage
Get-VMSwitch | Select-Object -Property Name,BandwidthPercentage

# Verify VMQ NIC's
Get-NetAdapterVmq