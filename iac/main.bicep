targetScope = 'resourceGroup'

param location string = resourceGroup().location
param namePrefix string
param storageAccountType string = 'Standard_LRS'

var storageAccountName = '${namePrefix}storage'
var synapseName = '${namePrefix}synapse'
var defaultDataLakeStorageFilesystemName = 'synapsefs'

resource storage_account 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageAccountName
  kind: 'StorageV2'
  location: location
  properties:{
    minimumTlsVersion: 'TLS1_2'
    isHnsEnabled: true
  }
  sku: {
    name: storageAccountType
  }
}

resource storage_blob_services 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
  name:  '${storage_account.name}/default'
}

resource storage_container_synapse 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: '${storage_account.name}/default/${defaultDataLakeStorageFilesystemName}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn:[
    storage_blob_services
  ]
} 

resource synapse 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: synapseName
  location: location
  properties: {
    azureADOnlyAuthentication: true
    defaultDataLakeStorage:{
      accountUrl: 'https://${storage_account.name}.dfs.${environment().suffixes.storage}'
      filesystem: defaultDataLakeStorageFilesystemName
    }
  }
  identity:{
    type:'SystemAssigned'
  }
}

resource synapseFirewallAllowAll 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  name: 'allowAll'
  parent: synapse
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}