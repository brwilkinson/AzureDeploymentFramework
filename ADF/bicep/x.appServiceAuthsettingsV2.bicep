param applicationId string = '84a491fe-f713-42f9-8e13-66bfb5dcc09b'
param requireAuthentication bool = false
param siteName string = 'AEU2-PE-LAB-D1-fnDIS03'

resource authsettingsV 'Microsoft.Web/sites/config@2022-09-01' = {
  name: '${siteName}/authsettingsV2'
  properties: {
    platform: {
      enabled: requireAuthentication
      runtimeVersion: '~1'
    }
    globalValidation: {
      requireAuthentication:  requireAuthentication
      unauthenticatedClientAction: 'RedirectToLoginPage'
      redirectToProvider: 'azureactivedirectory'
    }
    identityProviders: {
      azureActiveDirectory: requireAuthentication ? {
        enabled: requireAuthentication
        registration: {
          openIdIssuer: 'https://sts.windows.net/${subscription().tenantId}/v2.0'
          clientId: applicationId
          clientSecretSettingName: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
        }
        login: {
          disableWWWAuthenticate: false
        }
        validation: {
          jwtClaimChecks: {}
          allowedAudiences: [
            'api://${applicationId}'
          ]
          defaultAuthorizationPolicy: {
            allowedPrincipals: {}
          }
        }
      } : null
    }
    login: {
      routes: {}
      tokenStore: {
        enabled: true
        tokenRefreshExtensionHours: json('72.0')
        fileSystem: {}
        azureBlobStorage: {}
      }
      preserveUrlFragmentsForLogins: false
      cookieExpiration: {
        convention: 'FixedTime'
        timeToExpiration: '08:00:00'
      }
      nonce: {
        validateNonce: true
        nonceExpirationInterval: '00:05:00'
      }
    }
    httpSettings: {
      requireHttps: true
      routes: {
        apiPrefix: '/.auth'
      }
      forwardProxy: {
        convention: 'NoProxy'
      }
    }
  }
}



