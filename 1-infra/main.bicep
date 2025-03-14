// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.
@description('Configuration array for Inference Models')
param modelsConfig array = []

@description('The tags for the resources')
param tagValues object = {
}

// Creates Azure dependent resources for Azure AI studio

@description('Azure region of the deployment')
param location string = resourceGroup().location

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)


// ------------------
//    RESOURCES
// ------------------

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

output projectName string = project.name
output projectId string = project.id
var projectEndoint = replace(replace(project.properties.discoveryUrl, 'https://', ''), '/discovery', '')
output projectConnectionString string = '${projectEndoint};${subscription().subscriptionId};${resourceGroup().name};${project.name}'
