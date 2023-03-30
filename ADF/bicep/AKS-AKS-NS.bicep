@secure()
param kubeConfig string

import 'kubernetes@1.0.0' with {
  namespace: 'default'
  kubeConfig: kubeConfig
}

resource test 'rbac.authorization.k8s.io/ClusterRoleBinding@v1' = {
  metadata: {
    name: 'test'
    
  }
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io'
    kind: 'ClusterRole'
    name: 'cluster-admin'
  }
  subjects: [
    {
      kind: 'ServiceAccount'
      name: 'default'
      namespace: 'default'
    }
    {
      kind: 'Group'
      name: 'default'
      namespace: 'kube-system'
    }
  ]
}


resource appsDeployment_azureVoteBack 'apps/Deployment@v1' = {
  metadata: {
    name: 'azure-vote-back'
  }
  spec: {
    replicas: 1
    selector: {
      matchLabels: {
        app: 'azure-vote-back'
      }
    }
    template: {
      metadata: {
        labels: {
          app: 'azure-vote-back'
        }
      }
      spec: {
        nodeSelector: {
          'kubernetes.io/os': 'linux'
        }
        containers: [
          {
            name: 'azure-vote-back'
            image: 'mcr.microsoft.com/oss/bitnami/redis:6.0.8'
            env: [
              {
                name: 'ALLOW_EMPTY_PASSWORD'
                value: 'yes'
              }
            ]
            resources: {
              requests: {
                cpu: '100m'
                memory: '128Mi'
              }
              limits: {
                cpu: '250m'
                memory: '256Mi'
              }
            }
            ports: [
              {
                containerPort: 6379
                name: 'redis'
              }
            ]
          }
        ]
      }
    }
  }
}

resource coreService_azureVoteBack 'core/Service@v1' = {
  metadata: {
    name: 'azure-vote-back'
  }
  spec: {
    ports: [
      {
        port: 6379
      }
    ]
    selector: {
      app: 'azure-vote-back'
    }
  }
}

resource appsDeployment_azureVoteFront 'apps/Deployment@v1' = {
  metadata: {
    name: 'azure-vote-front'
  }
  spec: {
    replicas: 1
    selector: {
      matchLabels: {
        app: 'azure-vote-front'
      }
    }
    template: {
      metadata: {
        labels: {
          app: 'azure-vote-front'
        }
      }
      spec: {
        nodeSelector: {
          'kubernetes.io/os': 'linux'
        }
        containers: [
          {
            name: 'azure-vote-front'
            image: 'mcr.microsoft.com/azuredocs/azure-vote-front:v1'
            resources: {
              requests: {
                cpu: '100m'
                memory: '128Mi'
              }
              limits: {
                cpu: '250m'
                memory: '256Mi'
              }
            }
            ports: [
              {
                containerPort: 80
              }
            ]
            env: [
              {
                name: 'REDIS'
                value: 'azure-vote-back'
              }
            ]
          }
        ]
      }
    }
  }
}

resource coreService_azureVoteFront 'core/Service@v1' = {
  metadata: {
    name: 'azure-vote-front'
  }
  spec: {
    type: 'LoadBalancer'
    ports: [
      {
        port: 80
      }
    ]
    selector: {
      app: 'azure-vote-front'
    }
  }
}
