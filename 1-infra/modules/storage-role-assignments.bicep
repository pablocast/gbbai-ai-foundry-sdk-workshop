param storageAccountName string
param userPrincipalId string
param searchServicePrincipalId string

resource storageService 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
  scope: resourceGroup()
}

resource storageBlobDataReader 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  scope: resourceGroup()
}

resource storageBlobDataContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  scope: resourceGroup()
}

resource storageRoleBlobDataReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageService
  name: guid(subscription().id, resourceGroup().id, storageBlobDataReader.id, storageService.id)
  properties: {
    principalId: userPrincipalId 
    roleDefinitionId: storageBlobDataReader.id
    principalType: 'User'
  }
}

resource storageRoleBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageService
  name: guid(subscription().id, resourceGroup().id, storageBlobDataContributor.id, storageService.id)
  properties: {
    principalId: userPrincipalId
    roleDefinitionId: storageBlobDataContributor.id
    principalType: 'User'
  }
}

resource storageRoleSearchService 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageService
  name: guid(subscription().id, resourceGroup().id, searchServicePrincipalId, storageService.id)
  properties: {
    principalId: searchServicePrincipalId
    roleDefinitionId: storageBlobDataContributor.id
    principalType: 'ServicePrincipal'
  }
}

