param vmSize string = ''
param adminUsername string
param adminPassword string {
  secure: true
}

module vnetMod './vnet.bicep' = {
  name: 'vnetMod'
  params: {
    vnetName: 'vNet'
  }
}

// vm1
module vm1 './vm.bicep' = {
    name: 'vm1'
  params: {
    vnet: vnetMod.outputs.results.vnet
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
    vmName: 'vm1'
  }
}

// vm2
module vm2 './vm.bicep' = {
    name: 'vm2'
  params: {
    vnet: vnetMod.outputs.results.vnet
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
    vmName: 'vm2'
  }
}

output results object = {
  vnet: vnetMod
  vm1: vm1
  vm2: vm2
}
