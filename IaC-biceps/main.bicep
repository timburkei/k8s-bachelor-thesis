@description('The name of the Managed Cluster resource.')
param clusterName string = 'aks-cluster-thesis'

@description('The location of the Managed Cluster resource.')
param location string = 'germanywestcentral'

@description('Optional DNS prefix to use with hosted Kubernetes API server FQDN.')
param dnsPrefix string

@description('Disk size (in GB) to provision for each of the agent pool nodes. This value ranges from 0 to 1023. Specifying 0 will apply the default disk size for that agentVMSize.')
@minValue(0)
@maxValue(30)
param osDiskSizeGB int = 0

@description('The number of nodes for the cluster.')
param agentCount int = 1

@description('The size of the Virtual Machine.')
param agentVMSize string = 'Standard_B2as_v2'

@description('User name for the Linux Virtual Machines.')
param linuxAdminUsername string

@description('Configure all linux machines with the SSH RSA public key string.')
param sshRSAPublicKey string

@description('The name of the Azure Storage Account.')
param storageAccountName string = 'stroageAccountThesis'

@description('The name of the Azure Service Bus namespace.')
param serviceBusNamespace string = 'multiagentbus'

@description('The name of the Azure Service Bus queue.')
param serviceBusQueue string = 'multiagent-queue'

resource aks 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Base'
    tier: 'Free'
  }
  properties: {
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: 'agentpool'
        osDiskSizeGB: osDiskSizeGB
        count: agentCount
        vmSize: agentVMSize
        osType: 'Linux'
        mode: 'System'
      }
    ]
    linuxProfile: {
      adminUsername: linuxAdminUsername
      ssh: {
        publicKeys: [
          {
            keyData: sshRSAPublicKey
          }
        ]
      }
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}
