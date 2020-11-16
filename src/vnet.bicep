param vnetName string = 'vNet'
param addressPrefix string = '10.1.0.0/16'
param location string = resourceGroup().location

output results object = {
  vnet: vnet
}

var subnet1 = {
  name: 'subnet1'
  properties: {
    addressPrefix: '10.1.1.0/24'
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
        locations: [
          'japaneast'
          'japanwest'
        ]
      }
    ]
  }
}

var subnet2 = {
    name: 'subnet2'
    properties: {
      addressPrefix: '10.1.2.0/24'
    }
}

// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/virtualnetworks
resource vnet 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
        subnet1
        subnet2
    ]
  }
}

