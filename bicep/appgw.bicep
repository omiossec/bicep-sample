/*
This Bicep file create two VM, a VNET with two subnet and an Application Gateway with one rule to route HTTP traffic to the two VM

*/

// default param and default variable
param defaultLocation string {
    default: 'northeurope'
}
var subscriptionID = subscription().id

// network related section
var networkConfig = {
    name: 'demo-vnet'
    prefix: '10.0.0.0/21'
    subnets: [
        {
            name: 'backend'
            ip: '10.0.0.0/24'
        }
        {
            name: 'front'
            ip: '10.0.1.0/24'
        }
    ]
}
resource vnet 'Microsoft.Network/virtualNetworks@2020-05-01' = {
    name: networkConfig.name
    location: defaultLocation
    properties: {
      addressSpace: {
        addressPrefixes: [
            networkConfig.prefix
        ]
      }
      subnets: [
        {
          name: networkConfig.subnets[0].name
          properties: {
            addressPrefix: networkConfig.subnets[0].ip
          }
        }
        {
            name: networkConfig.subnets[1].name
            properties: {
              addressPrefix: networkConfig.subnets[1].ip
          }
        }
      ]
    }
  }

param appGatewayName string {
    metadata: {
        description: 'Name of the App gateway'
      }
}
var appGatewayPublicIp = '${appGatewayName}-pip'


param websiteHostName string {
    metadata: {
        description: 'host name for the protected web site'
    }
}

resource appGatewayIp 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: appGatewayPublicIp
  location: defaultLocation
  sku: {
      name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

resource appGateway 'Microsoft.Network/applicationGateways@2020-05-01' = {
  name: appGatewayName
  location: defaultLocation
  properties: {
    sku: {
        name: 'Standard_v2'
        tier: 'Standard_v2'
    }
    gatewayIPConfigurations: [
        {
            name: 'appGatewayIpConfig'
            properties: {
                subnet: {
                    id: '${vnet.id}/subnets/${networkConfig.subnets[0].name}'
                }
            }
        }
    ]
    sslCertificates: []
    trustedRootCertificates: []
    frontendIPConfigurations: [
        {
            name: 'appGwPublicFrontendIp'
            properties: {
                privateIPAllocationMethod: 'Dynamic'
                publicIPAddress: {
                    id: appGatewayIp.id
                }
            }
        }
    ]
    frontendPorts: [
        {
            name: 'http-80'
            properties: {
                port: 80
            }
        }
    ]
    backendAddressPools: [
        {
            name: 'backend-pool'
            properties: {
                backendAddresses: []
            }
        }
    ]
    backendHttpSettingsCollection: [
        {
            name: 'backend-http-settings'
            properties: {
                port: 80
                protocol: 'http'
                cookieBasedAffinity: 'enabled'
                connectionDraining: {
                    enabled: true
                    drainTimeoutInSec: 60
                }
                pickHostNameFromBackendAddress: false 
                affinityCookieName: 'appcookie'
                requestTimeout: 30
            }
        }
    ]
    httpListeners: [
        {
            name: 'http-listener'
            properties: {
                frontendIPConfiguration: {
                    id: '${subscriptionID}/Microsoft.Network/applicationGateways/${appGatewayName}/frontendIPConfigurations/appGwPublicFrontendIp'
                }
                frontendPort: {
                    id: '${subscriptionID}/Microsoft.Network/applicationGateways/${appGatewayName}/frontendPorts/http-80'
                }
                protocol: 'Http' 
                hostName: websiteHostName
                hostNames: []
                requireServerNameIndication: false 
            }
        }
    ]
    urlPathMaps: []
    requestRoutingRules: [
        {
            name: 'http01-rule'
            properties: {
                ruleType: 'Basic'
                httpListener: {
                    id: '${subscriptionID}/Microsoft.Network/applicationGateways/${appGatewayName}/httpListeners/http-listener'
                }
                backendAddressPool: {
                    id: '${subscriptionID}/Microsoft.Network/applicationGateways/${appGatewayName}/backendAddressPools/backend-pool'
                }
                backendHttpSettings: {
                    id: '${subscriptionID}/Microsoft.Network/applicationGateways/${appGatewayName}/backendHttpSettingsCollection/backend-http-settings'
                }
            }
        }
    ]
    probes: []
    rewriteRuleSets: []
    redirectConfigurations: []
    privateLinkConfigurations: []
    enableHttp2: false
    autoscaleConfiguration: {
        minCapacity: 2
        maxCapacity: 15
    }
  }
}

// VM Section
param vmNamePrefix string {
    metadata: {
        description: 'Prefix used to create VM name'
      }
}
param vmSku string {
    allowed: [
        'Standard_F2s'
        'Standard_B2ms'
      ] 
}
param vmOS string {
    default: '2019-Datacenter'
    allowed: [
        '2016-Datacenter'
        '2016-Datacenter-Server-Core'
        '2016-Datacenter-Server-Core-smalldisk'
        '2019-Datacenter'
        '2019-Datacenter-Server-Core'
        '2019-Datacenter-Server-Core-smalldisk'
      ] 
}
param localAdminPassword string {
    secure: true
    metadata: {
        description: 'password for the windows VM'
    }
}


resource vmNic01 'Microsoft.Network/networkInterfaces@2017-06-01' = {
    name: '${vmNamePrefix}-01-nic'
    location: defaultLocation
    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            subnet: {
              id: '${vnet.id}/subnets/backend'
            }
            privateIPAllocationMethod: 'Dynamic'
            applicationGatewayBackendAddressPools: {
                id: '${subscriptionID}/Microsoft.Network/applicationGateways/${appGateway}/backendAddressPools/backend-pool'
            }
          }
        }
      ]
    }
  }

  resource vm01 'Microsoft.Compute/virtualMachines@2019-07-01' = {
    name: '${vmNamePrefix}-01-vm'
    location: defaultLocation
    properties: {
      osProfile: {
        computerName: '${vmNamePrefix}-01'
        adminUsername: 'localadm'
        adminPassword: localAdminPassword
        windowsConfiguration: {
          provisionVmAgent: true
        }
      }
      hardwareProfile: {
        vmSize: vmSku
      }
      storageProfile: {
        imageReference: {
          publisher: 'MicrosoftWindowsServer'
          offer: 'WindowsServer'
          sku: vmOS
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          name: '${vmNamePrefix}-01-os-vhd'
          caching: 'ReadWrite'
          managedDisk: {
              storageAccountType: 'Premium_LRS'
          }
          diskSizeGB: 127
        }

      }
      networkProfile: {
        networkInterfaces: [
          {
            properties: {
              primary: true
            }
            id: vmNic01.id
          }
        ]
      }
    }
  }



  resource vmNic02 'Microsoft.Network/networkInterfaces@2017-06-01' = {
    name: '${vmNamePrefix}-02-nic'
    location: defaultLocation
    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            subnet: {
              id: '${vnet.id}/subnets/backend'
            }
            privateIPAllocationMethod: 'Dynamic'
            applicationGatewayBackendAddressPools: {
                id: '${subscriptionID}/Microsoft.Network/applicationGateways/${appGateway}/backendAddressPools/backend-pool'
            }
          }
        }
      ]
    }
  }

  resource vm02 'Microsoft.Compute/virtualMachines@2019-07-01' = {
    name: '${vmNamePrefix}-02-vm'
    location: defaultLocation
    properties: {
      osProfile: {
        computerName: '${vmNamePrefix}-02'
        adminUsername: 'localadm'
        adminPassword: localAdminPassword
        windowsConfiguration: {
          provisionVmAgent: true
        }
      }
      hardwareProfile: {
        vmSize: vmSku
      }
      storageProfile: {
        imageReference: {
          publisher: 'MicrosoftWindowsServer'
          offer: 'WindowsServer'
          sku: vmOS
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          name: '${vmNamePrefix}-02-os-vhd'
          caching: 'ReadWrite'
          managedDisk: {
              storageAccountType: 'Premium_LRS'
          }
          diskSizeGB: 127
        }

      }
      networkProfile: {
        networkInterfaces: [
          {
            properties: {
              primary: true
            }
            id: vmNic02.id
          }
        ]
      }
    }
  }

  resource avSet 'Microsoft.Compute/availabilitySets@2019-07-01' = {
    name: '${vmNamePrefix}-avset'
    location: defaultLocation
    sku: {
        name: 'Aligned'
    }
    properties: {
        platformUpdateDomainCount: 5
        platformFaultDomainCount: 3
        virtualMachines: [
            {
                id: vm02.id
            }
            {
                id: vm01.id
            }
        ]
    }
  }