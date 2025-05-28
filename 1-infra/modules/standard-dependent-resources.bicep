// Creates Azure dependent resources for Azure AI Agent Service standard agent setup

@description('Azure region of the deployment')
param location string = resourceGroup().location

@description('Tags to add to the resources')
param tags object = {}

@description('AI services name')
param aiServicesName string

@description('The name of the Key Vault')
param keyvaultName string

@description('The name of the AI Search resource')
param aiSearchName string

@description('The name of the Log Analytics workspace')
param logAnalyticsName string

@description('The name of the Application Insights resource')
param applicationInsightsName string

@description('The name of the container registry')
param containerRegistryName string

@description('Name of the storage account')
param storageName string

var storageNameCleaned = replace(storageName, '-', '')

@description('The name of the AI Services resource')
param modelsConfig array = []

@description('The AI Service Account full ARM Resource ID. This is an optional field, and if not provided, the resource will be created.')
param aiServiceAccountResourceId string

@description('The AI Search Service full ARM Resource ID. This is an optional field, and if not provided, the resource will be created.')
param aiSearchServiceResourceId string 

@description('The AI Storage Account full ARM Resource ID. This is an optional field, and if not provided, the resource will be created.')
param aiStorageAccountResourceId string 

@description('Bing Search Service name')
param bingSearchName string 

var aiServiceExists = aiServiceAccountResourceId != ''
var acsExists = aiSearchServiceResourceId != ''
var aiStorageExists = aiStorageAccountResourceId != ''

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyvaultName
  location: location
  tags: tags
  properties: {
    createMode: 'default'
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
    enableRbacAuthorization: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: 7
    tenantId: subscription().tenantId
  }
}


var aiServiceParts = split(aiServiceAccountResourceId, '/')

resource existingAIServiceAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = if (aiServiceExists) {
  name: aiServiceParts[8]
  scope: resourceGroup(aiServiceParts[2], aiServiceParts[4])
}

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = if(!aiServiceExists) {
  name: aiServicesName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices' 
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: toLower('${(aiServicesName)}')
    publicNetworkAccess: 'Enabled'
  }
}

resource bingSearch 'Microsoft.Bing/accounts@2020-06-10' = {
  name: bingSearchName
  location: 'global'
  kind: 'Bing.Grounding'
  sku: {
    name: 'G1'
  }
}


@batchSize(1)
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = [for model in modelsConfig: if(length(modelsConfig) > 0) {
  name: model.name
  parent: aiServices
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

var acsParts = split(aiSearchServiceResourceId, '/')

resource existingSearchService 'Microsoft.Search/searchServices@2024-06-01-preview' existing = if (acsExists) {
  name: acsParts[8]
  scope: resourceGroup(acsParts[2], acsParts[4])
}
resource aiSearch 'Microsoft.Search/searchServices@2024-06-01-preview' = if(!acsExists) {
  name: aiSearchName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    authOptions: { aadOrApiKey: { aadAuthFailureMode: 'http401WithBearerChallenge'}}
    encryptionWithCmk: {
      enforcement: 'Unspecified'
    }
    hostingMode: 'default'
    partitionCount: 1
    publicNetworkAccess: 'enabled'
    replicaCount: 1
    semanticSearch: 'standard'
  }
  sku: {
    name: 'standard'
  }
}

var aiStorageParts = split(aiStorageAccountResourceId, '/')

resource existingAIStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = if (aiStorageExists) {
  name: aiStorageParts[8]
  scope: resourceGroup(aiStorageParts[2], aiStorageParts[4])
}

// Some regions doesn't support Standard Zone-Redundant storage, need to use Geo-redundant storage
param noZRSRegions array = ['southindia', 'westus',  'northcentralus']
param sku object = contains(noZRSRegions, location) ? { name: 'Standard_GRS' } : { name: 'Standard_ZRS' }

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = if(!aiStorageExists) {
  name: storageNameCleaned
  location: location
  kind: 'StorageV2'
  sku: sku
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      virtualNetworkRules: []
    }
    allowSharedKeyAccess: false
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
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
  name: applicationInsightsName
  location: location
  tags: {}
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    // BCP037: Not yet added to latest API: https://github.com/Azure/bicep-types-az/issues/2048
    #disable-next-line BCP037
    CustomMetricsOptedInType: 'WithDimensions'

  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2019-05-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: true
  }
  tags: {}
}

output aiServicesName string =  aiServiceExists ? existingAIServiceAccount.name : aiServicesName
output aiservicesID string = aiServiceExists ? existingAIServiceAccount.id : aiServices.id
output aiservicesTarget string = 'https://${aiServices.name}.cognitiveservices.azure.com'
output aiServiceAccountResourceGroupName string = aiServiceExists ? aiServiceParts[4] : resourceGroup().name
output aiServiceAccountSubscriptionId string = aiServiceExists ? aiServiceParts[2] : subscription().subscriptionId 

output aiSearchName string = acsExists ? existingSearchService.name : aiSearch.name
output aisearchID string = acsExists ? existingSearchService.id : aiSearch.id
output aiSearchServiceResourceGroupName string = acsExists ? acsParts[4] : resourceGroup().name
output aiSearchServiceSubscriptionId string = acsExists ? acsParts[2] : subscription().subscriptionId

output storageAccountName string = aiStorageExists ? existingAIStorageAccount.name :  storage.name
output storageId string =  aiStorageExists ? existingAIStorageAccount.id :  storage.id
output storageAccountResourceGroupName string = aiStorageExists ? aiStorageParts[4] : resourceGroup().name
output storageAccountSubscriptionId string = aiStorageExists ? aiStorageParts[2] : subscription().subscriptionId

output bingSearchId string =  bingSearch.id
output bingSearchName string =  bingSearch.name
output bingSearchKey string = bingSearch.listKeys().key1

output keyvaultId string = keyVault.id

output logAnalyticsId string = logAnalytics.id
output logAnalyticsName string = logAnalytics.name

output applicationInsightsId string = applicationInsights.id
output applicationInsightsName string = applicationInsights.name

output containerRegistryId string = containerRegistry.id
output containerRegistryName string = containerRegistry.name

var searchKeys = aiSearch.listAdminKeys()
output azureSearchApiKey string = searchKeys.primaryKey

output aiSearchEndpoint string = 'https://${aiSearch.name}.search.windows.net/'
output openAIEndpoint string = 'https://${aiServices.name}.openai.azure.com/'
output aiSearchPrincipalId string = aiSearch.identity.principalId
