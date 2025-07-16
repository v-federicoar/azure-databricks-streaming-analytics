targetScope = 'resourceGroup'

param eventHubNamespaceName string = 'evhns-streaming'
param databricksWorkspaceName string = 'dbw-streaming'
param cosmosDatabaseAccountName string = 'coscas-streaming'
param logAnalyticsWorkspaceName string = 'log-streaming'
param logAnalyticsWorkspaceRegion string = resourceGroup().location
param location string = resourceGroup().location

var dataBricksResourceGroup = '${resourceGroup().name}-${databricksWorkspaceName}-${uniqueString(resourceGroup().name,'-',databricksWorkspaceName)}'

resource logAnalyticsWorkspace 'Microsoft.Operationalinsights/workspaces@2025-02-01' = {
  name: logAnalyticsWorkspaceName
  location: logAnalyticsWorkspaceRegion
  properties: {
    sku: {
      name: 'pergb2018'
    }
    retentionInDays: 30
  }
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  resource eventHubsResourcesRide 'eventhubs@2024-01-01' = {
    name: 'taxi-ride-eh'
    properties: {
      messageRetentionInDays: 3
      partitionCount: 8
    }
    resource eventHubsConsumerGroupRide 'consumerGroups@2024-01-01' = {
      name: 'taxi-ride-eh-cg'
      properties: {}
    }
    resource eventHubsAuthorizationRuleRide 'authorizationRules@2024-01-01' = {
      name: 'taxi-ride-eh-ar'
      properties: {
        rights: [
          'Listen'
          'Send'
        ]
      }
    }
  }
  resource eventHubsResourcesFare 'eventhubs@2024-01-01' = {
    name: 'taxi-fare-eh'
    properties: {
      messageRetentionInDays: 3
      partitionCount: 8
    }
    resource eventHubsConsumerGroupFare 'consumerGroups@2024-01-01' = {
      name: 'taxi-fare-eh-cg'
      properties: {}
    }
    resource eventHubsAuthorizationRuleFare 'authorizationRules@2024-01-01' = {
      name: 'taxi-fare-eh-ar'
      properties: {
        rights: [
          'Listen'
          'Send'
        ]
      }
    }
  }
}

resource eventHubDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'eventhub-logs'
  scope: eventHubNamespace
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'ArchiveLogs'
        enabled: true
      }
      {
        category: 'OperationalLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource databricksWorkspace 'Microsoft.Databricks/workspaces@2025-03-01-preview' = {
  name: databricksWorkspaceName
  location: location
  sku: {
    name: 'premium'
  }
  properties: {
    managedResourceGroupId: '${subscription().id}/resourceGroups/${dataBricksResourceGroup}'
  }
}

resource databricksDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'databricks-logs'
  scope: databricksWorkspace
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'jobs'
        enabled: true
      }
      {
        category: 'clusters'
        enabled: true
      }
      {
        category: 'dbfs'
        enabled: true
      }
      {
        category: 'notebook'
        enabled: true
      }
      {
        category: 'workspace'
        enabled: true
      }
    ]
  }
}

resource cosmosDatabaseAccount 'Microsoft.DocumentDB/databaseAccounts@2025-04-15' = {
  name: cosmosDatabaseAccountName
  location: location
  kind: 'GlobalDocumentDB'
  tags: {
    defaultExperience: 'Cassandra'
  }
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    capabilities: [
      {
        name: 'EnableCassandra'
      }
    ]
  }
  resource cassandraKeyspace 'cassandraKeyspaces@2025-04-15' = {
    name: 'newyorktaxi'
    location: location
    properties: {
      resource: {
        id: 'newyorktaxi'
      }
    }
    // Create Cassandra Table
    resource cassandraTable 'tables@2025-04-15' = {
      name: 'neighborhoodstats'
      location: location
      properties: {
        options: {
          throughput: 4000
        }
        resource: {
          id: 'neighborhoodstats'
          schema: {
            clusterKeys: [
              {
                name: 'window_end'
                orderBy: 'Asc'
              }
            ]
            columns: [
              { name: 'neighborhood', type: 'text' }
              { name: 'window_end', type: 'timestamp' }
              { name: 'number_of_rides', type: 'bigint' }
              { name: 'total_fare_amount', type: 'double' }
              { name: 'total_tip_amount', type: 'double' }
              { name: 'average_fare_amount', type: 'double' }
              { name: 'average_tip_amount', type: 'double' }
            ]
            partitionKeys: [
              { name: 'neighborhood' }
            ]
          }
        }
      }
    }
  }
}

resource cosmosDbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'cosmosdb-logs'
  scope: cosmosDatabaseAccount
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'CassandraRequests'
        enabled: true
      }
      {
        category: 'GremlinRequests'
        enabled: true
      }
      {
        category: 'TableApiRequests'
        enabled: true
      }
      {
        category: 'QueryRuntimeStatistics'
        enabled: true
      }
    ]
  }
}

output cosmosDb object = {
  username: cosmosDatabaseAccount.name
  hostName: '${cosmosDatabaseAccount.name}.cassandra.cosmos.azure.com'
  secret: cosmosDatabaseAccount.listKeys().primaryMasterKey
}

output eventHubs object = {
  ride: eventHubNamespace::eventHubsResourcesRide::eventHubsAuthorizationRuleRide.listKeys().primaryConnectionString
  fare: eventHubNamespace::eventHubsResourcesFare::eventHubsAuthorizationRuleFare.listKeys().primaryConnectionString
}
