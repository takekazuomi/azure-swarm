param location string = resourceGroup().location
param vmSku string = 'Standard_D1_v2'
param vmssName string
param instanceCount int {
  default:  1
  minValue: 1
  maxValue: 100
  metadata: {
    description: 'Number of VM instances (100 or less).'
  }
}
param adminUsername string {
  metadata: {
    description: 'Admin username on all VMs.'
  }
}

param authenticationType string {
  default: 'sshPublicKey'
  allowed: [
    'sshPublicKey'
    'password'
  ]
  metadata: {
    description: 'Type of authentication to use on the Virtual Machine. SSH key is recommended.'
  }
}

param adminPasswordOrKey string {
  secure: true
  metadata: {
    description: 'SSH Key or password for the Virtual Machine. SSH key is recommended.'
  }
}

param _artifactsLocation string {
  default: 'https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/201-vmss-bottle-autoscale/'
  metadata: {
    description: 'The base URI where artifacts required by this template are located'
  }
}

param _artifactsLocationSasToken string {
  secure: true
  default: ''
  metadata: {
    description: 'The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated'
  }
}

var addressPrefix = '10.0.0.0/16'
var subnetPrefix =  '10.0.0.0/24'
var virtualNetworkName = '${vmssName}vnet'
var publicIPAddressName = '${vmssName}pip'
var subnetName = '${vmssName}subnet'
var loadBalancerName = '${vmssName}lb'
var publicIPAddressID = resourceId('Microsoft.Network/publicIPAddresses', publicIPAddressName)
var natPoolName = '${vmssName}natpool'
var natPool2Name = '${vmssName}natpool2'
var bePoolName = '${vmssName}bepool'
var natStartPort = 50000
var natEndPort = 50120
var natBackendPort = 22
var nicName = '${vmssName}nic'
var ipConfigName = '${vmssName}ipconfig'
var frontEndIPConfigID = resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations',loadBalancerName, 'loadBalancerFrontEnd')

var osType = {
  publisher: 'Canonical'
  offer: 'UbuntuServer'
  sku: '16.04-LTS'
  version: 'latest'
}

var imageReference = osType

var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}


// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/virtualnetworks
resource vnet 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}

// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/publicipaddresses
resource publicIP 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  location: location
  name: publicIPAddressName
  properties: {
      publicIPAllocationMethod: 'Dynamic'
      publicIPAddressVersion: 'IPv4'
      idleTimeoutInMinutes: 4
      dnsSettings: {
        domainNameLabel: vmssName
      }
  }
}

// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/loadbalancers
resource lb 'Microsoft.Network/loadBalancers@2020-06-01' = {
  name: loadBalancerName
  location: location
  dependsOn: [
    publicIP
  ]
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontEnd'
        properties: {
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: bePoolName
      }
    ]
    inboundNatPools: [
      {
        name: natPoolName
        properties: {
          frontendIPConfiguration: {
            id: frontEndIPConfigID
          }
          protocol: 'Tcp'
          frontendPortRangeStart: natStartPort
          frontendPortRangeEnd: natEndPort
          backendPort: natBackendPort
        }
      }
      {
        name: natPool2Name
        properties: {
          frontendIPConfiguration: {
            id: frontEndIPConfigID
          }
          protocol: 'Tcp'
          frontendPortRangeStart: 9000
          frontendPortRangeEnd: 9120
          backendPort: 9000
        }
      }
    ]
  }
}

// https://docs.microsoft.com/en-us/azure/templates/microsoft.compute/virtualmachinescalesets
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2020-06-01' = {
  name: vmssName
  location: location
  sku: {
    name: vmSku
    tier: 'Standard'
    capacity: instanceCount
  }
  dependsOn: [
    lb
    vnet
  ]
  properties: {
    overprovision: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
        }
        imageReference: imageReference
      }
      osProfile: {
        computerNamePrefix: vmssName
        adminUsername: adminUsername
        adminPassword: adminPasswordOrKey
        linuxConfiguration: any(authenticationType == 'password' ? null : 'linuxConfiguration') // TODO: workaround for https://github.com/Azure/bicep/issues/449
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: nicName
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: ipConfigName
                  properties: {
                    subnet: {
                      id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, bePoolName)
                      }
                    ]
                    loadBalancerInboundNatPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/inboundNatPools',loadBalancerName, natPoolName)
                      }
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/inboundNatPools', loadBalancerName, natPool2Name)
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'lapextension'
            properties: {
              publisher: 'Microsoft.Azure.Extensions'
              type: 'CustomScript'
              typeHandlerVersion: '2.0'
              autoUpgradeMinorVersion: true
              settings: {
                fileUris: [
                  uri(_artifactsLocation, 'installserver.sh${_artifactsLocationSasToken}')
                  uri(_artifactsLocation, 'workserver.py${_artifactsLocationSasToken}')
                ]
                commandToExecute: 'bash installserver.sh'
              }
            }
          }
        ]
      }
    }
  }
}

resource autoScale 'Microsoft.Insights/autoscaleSettings@2015-04-01' = {
  name: 'autoscalehost'
  location: location
  dependsOn: [
    vmss
  ]
  properties: {
    name: 'autoscalehost'
    targetResourceUri: resourceId('Microsoft.Compute/virtualMachineScaleSets', vmssName)
    enabled: true
    profiles: [
      {
        name: 'Profile1'
        capacity: {
          minimum: '1'
          maximum: '10'
          default: '1'
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: resourceId('Microsoft.Compute/virtualMachineScaleSets', vmssName)
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 60
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT1M'
            }
          }
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: resourceId('Microsoft.Compute/virtualMachineScaleSets', vmssName)
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT1M'
            }
          }
        ]
      }
    ]
  }
}
