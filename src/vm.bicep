param vnet object
param vmName string = 'linux-vm'
param vmSize string = 'Standard_B1s'
param adminUsername string = 'takekazu.omi'
param adminPassword string {
  secure: true
}
param subnetName string = 'subnet1'
param customData string = ''
param location string = resourceGroup().location

output results object = {
  vm: vm
  nic: nic
  nsg: nsg
  publicIP: publicIP
  diagstg: stg
}

var nicName = '${vmName}-nic1'
var nsgName = '${vmName}-nsg'
var diskName = '${vmName}-osdisk-1'
var publicIPName = '${vmName}-public-ip-1'
// get vnet name from vnet id. Workaround, vnet.name is missing.
var vnetName = last(split(vnet.resourceId, '/'))
var subnetId = resourceId(vnet.resourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)


var storageAccountName = take('${replace(vmName,'-', '')}diag${uniqueString(resourceGroup().id)}', 24)
//var subnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, subnetName)

var imageReference =  {
  publisher: 'Canonical'
  offer: 'UbuntuServer'
  sku: '18.04-LTS'
  version: 'latest'
}

// https://docs.microsoft.com/en-us/azure/templates/microsoft.compute/virtualmachines
resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: vmName
  location: location
  dependsOn: [
    publicIP
  ]
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        osType: 'Linux'
        name: diskName
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: 30
      }
      dataDisks: []
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: customData == '' ? null : customData
      linuxConfiguration: {
        provisionVMAgent: true
      }
      secrets: []
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: stg.properties.primaryEndpoints.blob
      }
    }
  }
}

// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/2020-05-01/networkinterfaces
resource nic 'Microsoft.Network/networkInterfaces@2020-05-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/publicipaddresses
resource publicIP 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: publicIPName
  location: location
  properties: {
      publicIPAllocationMethod: 'Dynamic'
      publicIPAddressVersion: 'IPv4'
      idleTimeoutInMinutes: 4
  }
  sku: {
      name: 'Basic'
  }
}

// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/networksecuritygroups
resource nsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: nsgName
  location: location
  properties: {
      securityRules: [
      ]
  }
}

// https://docs.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts
resource stg 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  kind: 'Storage'
  sku: {
     name: 'Standard_LRS'
     tier: 'Standard'
  }
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: [
        {
          id: subnetId
          action: 'Allow'
        }
      ]
      defaultAction: 'Deny'
    }
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

