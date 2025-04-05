// Assigns the necessary roles to the AI project

@description('Name of the AI Services resource')
param aiServicesName string

@description('Name of the Search Service')
param searchServiceName string

@description('Principal ID of the AI project')
param aiProjectPrincipalId string

@description('Resource ID of the AI project')
param aiProjectId string

@description('Resource ID of the AI Search resource')
param userPrincipalId string

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-06-01-preview' existing = {
  name: aiServicesName
  scope: resourceGroup()
}

resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: searchServiceName
  scope: resourceGroup()
}

resource cognitiveServicesContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68'
  scope: resourceGroup()

}

resource cognitiveServicesContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01'= {
  scope: aiServices
  name: guid(aiServices.id, cognitiveServicesContributorRole.id, aiProjectId)
  properties: {  
    principalId: aiProjectPrincipalId
    roleDefinitionId: cognitiveServicesContributorRole.id
    principalType: 'ServicePrincipal'
  }
}

resource cognitiveServicesOpenAIUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  scope: resourceGroup()
}

resource cognitiveServicesOpenAIUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiServices
  name: guid(aiProjectId, cognitiveServicesOpenAIUserRole.id, aiServices.id)
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: cognitiveServicesOpenAIUserRole.id
    principalType: 'ServicePrincipal'
  }
}

resource cognitiveServicesUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'a97b65f3-24c7-4388-baec-2e87135dc908'
  scope: resourceGroup()
}

resource cognitiveServicesUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiServices
  name: guid(aiProjectId, cognitiveServicesUserRole.id, aiServices.id)
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: cognitiveServicesUserRole.id
    principalType: 'ServicePrincipal'
  }
}

// Integrated vectorization - access to models
resource cognitiveServicesRoleSearch 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiServices
  name: guid(aiProjectId, cognitiveServicesOpenAIUserRole.id, searchService.id)
  properties: {
    principalId: searchService.identity.principalId
    roleDefinitionId: cognitiveServicesOpenAIUserRole.id
    principalType: 'ServicePrincipal'
  }
}

// Assigns the necessary roles to the user
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
    name: guid(subscription().id, resourceGroup().id, cognitiveServicesOpenAIUserRole.id)
    scope: resourceGroup()
    properties: {
      principalType: 'User'
      principalId: userPrincipalId
      roleDefinitionId: cognitiveServicesOpenAIUserRole.id
    }
  }

// For Cognitive Services Reader Role user
resource cognitiveServicesRoleUser 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, resourceGroup().id, cognitiveServicesUserRole.id)
  scope: resourceGroup()
  properties: {
    principalType: 'User'
    principalId: userPrincipalId
    roleDefinitionId: cognitiveServicesUserRole.id
  }
}
