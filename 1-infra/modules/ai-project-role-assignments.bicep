@description('AI Project name')
param aiProjectName string

@description('Resource ID of the AI Search resource')
param userPrincipalId string

@description('AI Services name')
param aiServicesName string

resource aiProject 'Microsoft.MachineLearningServices/workspaces@2024-10-01-preview' existing = {
  name: aiProjectName
  scope: resourceGroup()
}

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-06-01-preview' existing = {
  name: aiServicesName
  scope: resourceGroup()
}

resource azureMLDataScientistRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'f6c7c914-8db3-469d-8ca1-694a8f32e121'
  scope: subscription()
}

resource azureMLDataScientistUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiProject.id, azureMLDataScientistRole.id, userPrincipalId)
  scope: aiProject
  properties: {
    roleDefinitionId: azureMLDataScientistRole.id
    principalType: 'User'
    principalId: userPrincipalId
  }
}

resource azureMLDataScientistManagedIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiProject.id, azureMLDataScientistRole.id, aiServices.id)
  scope: aiProject
  properties: {
    roleDefinitionId: azureMLDataScientistRole.id
    principalType: 'ServicePrincipal'
    principalId: aiServices.identity.principalId
  }
}


// to read connections
resource azureConnectionSecretsReader 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'ea01e6af-a1c1-4350-9563-ad00f8c72ec5'
  scope: subscription()
}

resource azureConnectionSecretsReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiProject.id, azureConnectionSecretsReader.id, aiServices.id)
  scope: aiProject
  properties: {
    roleDefinitionId: azureConnectionSecretsReader.id
    principalType: 'User'
    principalId: userPrincipalId
  }
}
