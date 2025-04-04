// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.
@description('Configuration array for Inference Models')
param modelsConfig array = []

@description('The tags for the resources')
param tagValues object = {
}

@description('The principal ID of the user to assign the role to')
param principalId string = ''

// Creates Azure dependent resources for Azure AI studio
@description('Azure region of the deployment')
param location string = resourceGroup().location

@description('The SKU for the Search Service')
param searchServiceSku string 
param searchServiceReplicaCount int = 1
param searchServicePartitionCount int = 1

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)


// ------------------
//    RESOURCES
// ------------------

resource bingSearch 'Microsoft.Bing/accounts@2020-06-10' = {
  name: 'bingsearch-${resourceSuffix}'
  location: 'global'
  kind: 'Bing.Grounding'
  sku: {
    name: 'G1'
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-${resourceSuffix}'
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'insights-${resourceSuffix}'
  location: location
  tags: tagValues
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    // BCP037: Not yet added to latest API: https://github.com/Azure/bicep-types-az/issues/2048
    #disable-next-line BCP037
    CustomMetricsOptedInType: 'WithDimensions'

  }
}

resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: 'aiservices-${resourceSuffix}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  properties: {
    customSubDomainName: toLower('aiservices-${resourceSuffix}')
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
    disableLocalAuth: false
  }
}

@batchSize(1)
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = [for model in modelsConfig: if(length(modelsConfig) > 0) {
  name: model.name
  parent: account
  sku: {
    name: model.sku
    capacity: model.capacity
  }
  properties: {
    model: {
      format: model.publisher
      name: model.name
      version: model.version
    }
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}]


resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: 'search-${resourceSuffix}'
  location: location
  sku: {
    name: searchServiceSku
  }
  properties: {
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    replicaCount: searchServiceReplicaCount
    partitionCount: searchServicePartitionCount
  }
}


resource storageAccount 'Microsoft.Storage/storageAccounts@2019-04-01' = {
  name: 'storage${resourceSuffix}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    supportsHttpsTrafficOnly: true
  }
  tags: tagValues
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: 'vault-${resourceSuffix}'
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    enableRbacAuthorization: true
    accessPolicies: []
  }
  tags: tagValues
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2019-05-01' = {
  name: 'acr${resourceSuffix}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: true
  }
  tags: tagValues
}

resource hub 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  name: 'aihub-${resourceSuffix}'
  kind: 'Hub'
  location: location
  identity: {
    type: 'systemAssigned'
  }
  sku: {
    tier: 'Standard'
    name: 'standard'
  }
  properties: {
    description: 'Azure AI hub'
    friendlyName: 'AIHub'
    storageAccount: storageAccount.id
    keyVault: keyVault.id
    applicationInsights: applicationInsights.id
    containerRegistry: containerRegistry.id
    hbiWorkspace: false
  }
  tags: tagValues
}

resource project 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  name: 'project-${resourceSuffix}'
  kind: 'Project'
  location: location
  identity: {
    type: 'systemAssigned'
  }
  sku: {
    tier: 'Standard'
    name: 'standard'
  }
  properties: {
    description: 'Azure AI project'
    friendlyName: 'AIProject'
    hbiWorkspace: false
    hubResourceId: hub.id
  }
  tags: tagValues
}

// AI Services Connection
resource connection 'Microsoft.MachineLearningServices/workspaces/connections@2024-04-01-preview' = {
  name: 'aiServicesConnection'
  parent: hub
  properties: {
    category: 'AIServices'
    target: account.properties.endpoints['Azure AI Model Inference API']
    authType: 'AAD'
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: account.id
    }
  }
}

// BingSearch Connection
resource bingSearchConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-04-01-preview' = {
  name: 'BingSearch'
  parent: hub
  properties: {
    category: 'ApiKey'
    authType: 'ApiKey'
    isSharedToAll: true
    target: 'https://api.bing.microsoft.com/'
    metadata: {
      ApiVersion: '2024-02-01'
      ApiType: 'azure'
      ResourceId: bingSearch.id
      location: 'global'
    }
    credentials: {
      key: bingSearch.listKeys().key1
    }
  }
}

// Search Service Connection
resource AISearchConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-04-01-preview' = {
  name: 'SearchConnection'
  parent: hub
  properties: {
    category: 'CognitiveSearch'
    authType: 'ApiKey'
    isSharedToAll: true
    target: 'https://${searchService.name}-${resourceSuffix}.search.windows.net'
    enforceAccessToDefaultSecretStores: true
    metadata: {
      ApiVersion: '2024-02-01'
      ApiType: 'azure'
    }
    credentials: {
      key: searchService.listAdminKeys().primaryKey
    }
  }
}

// Roles for AI Services
resource cognitiveServicesContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68'
  scope: resourceGroup()

}
resource cognitiveServicesContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01'= {
  scope: account
  name: guid(account.id, cognitiveServicesContributorRole.id, project.id)
  properties: {  
    principalId: project.identity.principalId
    roleDefinitionId: cognitiveServicesContributorRole.id
    principalType: 'ServicePrincipal'
  }
}


resource cognitiveServicesOpenAIUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  scope: resourceGroup()
}
resource cognitiveServicesOpenAIUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: account
  name: guid(account.id, cognitiveServicesOpenAIUserRole.id, project.id)
  properties: {
    principalId: project.identity.principalId
    roleDefinitionId: cognitiveServicesOpenAIUserRole.id
    principalType: 'ServicePrincipal'
  }
}

resource cognitiveServicesUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'a97b65f3-24c7-4388-baec-2e87135dc908'
  scope: resourceGroup()
}
resource cognitiveServicesUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: account
  name: guid(account.id, cognitiveServicesUserRole.id, project.id)
  properties: {
    principalId: project.identity.principalId
    roleDefinitionId: cognitiveServicesUserRole.id
    principalType: 'ServicePrincipal'
  }
}


// Roles for Integrated Vectorization
resource searchIndexDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  scope: resourceGroup()
}
resource searchIndexDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(subscription().id, resourceGroup().id, searchIndexDataContributorRole.id, searchService.id)
  properties: {
    principalId: project.identity.principalId
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
  name: guid(subscription().id, resourceGroup().id, searchServiceContributorRole.id, searchService.id)
  properties: {
    principalId: project.identity.principalId
    roleDefinitionId: searchServiceContributorRole.id
    principalType: 'ServicePrincipal'
  }
}

// For integrated vectorization access to storage
resource searchServiceStorageReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  scope: resourceGroup()
}
resource storageRoleSearchService 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(subscription().id, resourceGroup().id, searchServiceStorageReaderRole.id, searchService.id)
  properties: {
    principalId: project.identity.principalId
    roleDefinitionId: searchServiceStorageReaderRole.id
    principalType: 'ServicePrincipal'
  }
}

// Search Index Data Contributor
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, resourceGroup().id, searchIndexDataContributorRole.id)
  scope: resourceGroup()
  properties: {
    principalType: 'User'
    principalId: principalId
    roleDefinitionId: searchIndexDataContributorRole.id
  }
}

// MCP Servers
module mcpServer 'container-app.bicep' = {
  name: 'mcpServer'
  params: {
    location: location
    resourceSuffix: resourceSuffix  
    lawName: logAnalytics.name
    containerRegistryName: containerRegistry.name
  }
  scope: resourceGroup()
}


output projectName string = project.name
output projectId string = project.id
var projectEndoint = replace(replace(project.properties.discoveryUrl, 'https://', ''), '/discovery', '')
output projectConnectionString string = '${projectEndoint};${subscription().subscriptionId};${resourceGroup().name};${project.name}'

output bingConnectionName string = bingSearchConnection.name

output weatherMCPServerContainerAppResourceName string = mcpServer.outputs.weatherMCPServerContainerAppResourceName
output weatherMCPServerContainerAppFQDN string = mcpServer.outputs.weatherMCPServerContainerAppFQDN

output applicationInsightsName  string = applicationInsights.name
output containerRegistryName string = containerRegistry.name

output model_deployment_name string = modelDeployment[2].name
