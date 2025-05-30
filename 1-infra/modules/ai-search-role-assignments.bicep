// Assigns the necessary roles to the AI project

@description('Name of the AI Search resource')
param aiSearchName string

@description('Principal ID of the AI project')
param aiProjectPrincipalId string

@description('Resource ID of the AI project')
param aiProjectId string

@description('Resource ID of the AI Search resource')
param userPrincipalId string

resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: aiSearchName
  scope: resourceGroup()
}

// search roles
resource searchIndexDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  scope: resourceGroup()
}


resource searchIndexDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(aiProjectId, searchIndexDataContributorRole.id, searchService.id)
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: searchIndexDataContributorRole.id
    principalType: 'ServicePrincipal'
  }
}

resource searchServiceContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  scope: resourceGroup()
}

resource searchServiceContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(aiProjectId, searchServiceContributorRole.id, searchService.id)
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: searchServiceContributorRole.id
    principalType: 'ServicePrincipal'
  }
}

resource searchIndexDataReaderRole  'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
  scope: resourceGroup()
}
resource searchIndexDataReaderRoleRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(aiProjectId, searchIndexDataReaderRole.id, searchService.id)
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: searchIndexDataReaderRole.id
    principalType: 'ServicePrincipal'
  }
}


// integrated vectorization - access to storage account
resource searchServiceStorageReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  scope: resourceGroup()
}

resource storageRoleSearchService 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(subscription().id, resourceGroup().id, searchServiceStorageReaderRole.id, searchService.id)
  properties: {
    principalId: searchService.identity.principalId
    roleDefinitionId: searchServiceStorageReaderRole.id
    principalType: 'ServicePrincipal'
  }
}

// Search Index Data Contributor
resource userSearchIndexDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, resourceGroup().id, searchIndexDataContributorRole.id)
  scope: resourceGroup()
  properties: {
    principalType: 'User'
    principalId: userPrincipalId
    roleDefinitionId: searchIndexDataContributorRole.id
  }
}

resource userSearchServiceContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, resourceGroup().id, searchServiceContributorRole.id)
  scope: resourceGroup()
  properties: {
    principalType: 'User'
    principalId: userPrincipalId
    roleDefinitionId: searchServiceContributorRole.id
  }
}

resource userSearchIndexDataReaderRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, resourceGroup().id, searchIndexDataReaderRole.id)
  scope: resourceGroup()
  properties: {
    principalType: 'User'
    principalId: userPrincipalId
    roleDefinitionId: searchIndexDataReaderRole.id
  }
}


