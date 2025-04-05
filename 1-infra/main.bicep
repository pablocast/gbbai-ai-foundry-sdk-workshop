// Execute this main file to deploy Standard Agent setup resources
@description('The principal ID of the user to assign the role to')
param principalId string

@minLength(2)
@maxLength(12)
@description('Name for the AI resource and used to derive name of dependent resources.')
param aiHubName string = 'hub-demo'

@description('Friendly name for your Hub resource')
param aiHubFriendlyName string = 'Agents Hub resource'

@description('Description of your Azure AI resource displayed in AI studio')
param aiHubDescription string = 'This is an example AI resource for use in Azure AI Studio.'

@description('Name for the AI project resources.')
param aiProjectName string = 'project-demo'

@description('Friendly name for your Azure AI resource')
param aiProjectFriendlyName string = 'Agents Project resource'

@description('Description of your Azure AI resource displayed in AI studio')
param aiProjectDescription string = 'This is an example AI Project resource for use in Azure AI Studio.'

@description('Azure region used for the deployment of all resources.')
param location string = resourceGroup().location

@description('Set of tags to apply to all resources.')
param tags object = {}

@description('Name of the Azure AI Search account')
param aiSearchName string = 'agent-ai-search'

@description('Name of the Bing Search account')
param bingSearchName string = 'bing-search'

@description('Name of the Log Analytics workspace')
param logAnalyticsName string = 'log-analytics'

@description('Name for capabilityHost.')
param capabilityHostName string = 'caphost1'

@description('Name for ACRconnection.')
param containerRegistryName string = 'agentcontainerregistry'

@description('Name of the Application Insights resource')
param applicationInsightsName string = 'agent-appinsights'

@description('Name of the storage account')
param storageName string = 'agent-storage'

@description('Name of the Azure AI Services account')
param aiServicesName string = 'agent-ai-services'

@description('Configuration array for Inference Models')
param modelsConfig array = []

@description('AI Service Account kind: either AzureOpenAI or AIServices')
param aiServiceKind string = 'AIServices'

@description('The AI Service Account full ARM Resource ID. This is an optional field, and if not provided, the resource will be created.')
param aiServiceAccountResourceId string = ''

@description('The Ai Search Service full ARM Resource ID. This is an optional field, and if not provided, the resource will be created.')
param aiSearchServiceResourceId string = ''

@description('The Ai Storage Account full ARM Resource ID. This is an optional field, and if not provided, the resource will be created.')
param aiStorageAccountResourceId string = ''

// Variables
var name = toLower('${aiHubName}')
var projectName = toLower('${aiProjectName}')

// Create a short, unique suffix, that will be unique to each resource group
// var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 4)
param deploymentTimestamp string = utcNow('yyyyMMddHHmmss')
var uniqueSuffix = substring(uniqueString('${resourceGroup().id}-${deploymentTimestamp}'), 0, 4)

var aiServiceExists = aiServiceAccountResourceId != ''
var acsExists = aiSearchServiceResourceId != ''

var aiServiceParts = split(aiServiceAccountResourceId, '/')
var aiServiceAccountSubscriptionId = aiServiceExists ? aiServiceParts[2] : subscription().subscriptionId 
var aiServiceAccountResourceGroupName = aiServiceExists ? aiServiceParts[4] : resourceGroup().name

var acsParts = split(aiSearchServiceResourceId, '/')
var aiSearchServiceSubscriptionId = acsExists ? acsParts[2] : subscription().subscriptionId
var aiSearchServiceResourceGroupName = acsExists ? acsParts[4] : resourceGroup().name

// Dependent resources for the Azure Machine Learning workspace
module aiDependencies 'modules/standard-dependent-resources.bicep' = {
  name: 'dependencies-${name}-${uniqueSuffix}-deployment'
  params: {
    location: location
    storageName: '${storageName}${uniqueSuffix}'
    keyvaultName: 'kv-${name}-${uniqueSuffix}'
    aiServicesName: '${aiServicesName}${uniqueSuffix}'
    aiSearchName: '${aiSearchName}-${uniqueSuffix}'
    bingSearchName: '${bingSearchName}-${uniqueSuffix}'
    logAnalyticsName: '${logAnalyticsName}-${uniqueSuffix}'
    containerRegistryName: '${containerRegistryName}${uniqueSuffix}'
    applicationInsightsName: '${applicationInsightsName}-${uniqueSuffix}'
    tags: tags

     // Model deployment parameters
     modelsConfig: modelsConfig

     aiServiceAccountResourceId: aiServiceAccountResourceId
     aiSearchServiceResourceId: aiSearchServiceResourceId
     aiStorageAccountResourceId: aiStorageAccountResourceId
    }
}

module aiHub 'modules/standard-ai-hub.bicep' = {
  name: '${name}-${uniqueSuffix}-deployment'
  params: {
    // workspace organization
    aiHubName: '${name}-${uniqueSuffix}'
    aiHubFriendlyName: aiHubFriendlyName
    aiHubDescription: aiHubDescription
    location: location
    tags: tags

    aiSearchName: aiDependencies.outputs.aiSearchName
    aiSearchId: aiDependencies.outputs.aisearchID
    aiSearchServiceResourceGroupName: aiDependencies.outputs.aiSearchServiceResourceGroupName
    aiSearchServiceSubscriptionId: aiDependencies.outputs.aiSearchServiceSubscriptionId

    aiServicesName: aiDependencies.outputs.aiServicesName
    aiServiceKind: aiServiceKind
    aiServicesId: aiDependencies.outputs.aiservicesID
    aiServicesTarget: aiDependencies.outputs.aiservicesTarget
    aiServiceAccountResourceGroupName:aiDependencies.outputs.aiServiceAccountResourceGroupName
    aiServiceAccountSubscriptionId:aiDependencies.outputs.aiServiceAccountSubscriptionId
    
    bingSearchId: aiDependencies.outputs.bingSearchId
    bingSearchKey: aiDependencies.outputs.bingSearchKey

    keyVaultId: aiDependencies.outputs.keyvaultId
    storageAccountId: aiDependencies.outputs.storageId
    logAnalyticsId: aiDependencies.outputs.logAnalyticsId
    containerRegistryId: aiDependencies.outputs.containerRegistryId
    applicationInsightsId: aiDependencies.outputs.applicationInsightsId
  }
}

module aiProject 'modules/standard-ai-project.bicep' = {
  name: '${projectName}-${uniqueSuffix}-deployment'
  params: {
    // workspace organization
    aiProjectName: '${projectName}-${uniqueSuffix}'
    aiProjectFriendlyName: aiProjectFriendlyName
    aiProjectDescription: aiProjectDescription
    location: location
    tags: tags
    aiHubId: aiHub.outputs.aiHubID
    applicationInsightsId: aiDependencies.outputs.applicationInsightsId
  }
}

module aiServiceRoleAssignments 'modules/ai-service-role-assignments.bicep' = {
  name: 'ai-service-role-assignments-${projectName}-${uniqueSuffix}-deployment'
  scope: resourceGroup(aiServiceAccountSubscriptionId, aiServiceAccountResourceGroupName)
  params: {
    aiServicesName: aiDependencies.outputs.aiServicesName
    aiProjectPrincipalId: aiProject.outputs.aiProjectPrincipalId
    aiProjectId: aiProject.outputs.aiProjectResourceId
    searchServiceName: aiDependencies.outputs.aiSearchName
    userPrincipalId: principalId
  }
}

module aiSearchRoleAssignments 'modules/ai-search-role-assignments.bicep' = {
  name: 'ai-search-role-assignments-${projectName}-${uniqueSuffix}-deployment'
  scope: resourceGroup(aiSearchServiceSubscriptionId, aiSearchServiceResourceGroupName)
  params: {
    aiSearchName: aiDependencies.outputs.aiSearchName
    aiProjectPrincipalId: aiProject.outputs.aiProjectPrincipalId
    aiProjectId: aiProject.outputs.aiProjectResourceId
    userPrincipalId: principalId
  }
}

module aiProjectRoleAssignments 'modules/ai-project-role-assignments.bicep' = {
  name: 'ai-project-role-assignments-${projectName}-${uniqueSuffix}-deployment'
  params: {
    aiProjectName: aiProject.outputs.aiProjectName
    aiServicesName: aiDependencies.outputs.aiServicesName
    userPrincipalId: principalId
  }
}

module addCapabilityHost 'modules/add-capability-host.bicep' = {
  name: 'capabilityHost-configuration-${uniqueSuffix}-deployment'
  params: {
    capabilityHostName: '${uniqueSuffix}-${capabilityHostName}'
    aiHubName: aiHub.outputs.aiHubName
    aiProjectName: aiProject.outputs.aiProjectName
    acsConnectionName: aiHub.outputs.acsConnectionName
    aoaiConnectionName: aiHub.outputs.aoaiConnectionName
  }
  dependsOn: [
    aiSearchRoleAssignments,aiServiceRoleAssignments
  ]
}

module mcpServer 'modules/container-app.bicep' = {
  name: 'mcpServer'
  params: {
    location: location
    resourceSuffix: uniqueSuffix
    lawName: aiDependencies.outputs.logAnalyticsName
    containerRegistryName: aiDependencies.outputs.containerRegistryName
  }
  scope: resourceGroup(aiSearchServiceSubscriptionId, aiSearchServiceResourceGroupName)
}

output projectConnectionString string = aiProject.outputs.projectConnectionString
output weatherMCPServerContainerAppResourceName string = mcpServer.outputs.weatherMCPServerContainerAppResourceName
output weatherMCPServerContainerAppFQDN string = mcpServer.outputs.weatherMCPServerContainerAppFQDN

output applicationInsightsName  string = aiDependencies.outputs.applicationInsightsName
output containerRegistryName string = aiDependencies.outputs.containerRegistryName

output modelDeploymentName string = modelsConfig[2].name
output bingConnectionName string = aiHub.outputs.bingConnectionName
