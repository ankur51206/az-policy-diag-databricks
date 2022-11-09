# My Providers start 
provider "azurerm" {
  features {}
}

data "azurerm_management_group" "baringsroot" {
  display_name = "ankur management group"
}

# My Provider finish

data "azurerm_user_assigned_identity" "mi-cloudops-azpolicy" {
  name                = "MyIdentity"
  resource_group_name = "sample-1"
}

resource "azurerm_policy_definition" "storage_diaglogs" {
  name         = "diag-databricks"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "enable diagnostic setting for storage account"

  metadata = <<METADATA
    {
    "category": "General"
    }
METADATA

  parameters = <<PARAMETERS

		{
		"eventHubAuthorizationRuleId": {
			"type": "String",
			"metadata": {
				"displayName": "Event Hub Shared Access Policy Authorization Rule Id",
				"description": "Specify Event Hub Shared Access Policy Authorization Rule Id"
			}
		},
		"Location": {
			"type": "String",
			"metadata": {
				"displayName": "Resource Location",
				"description": "Resource Location must be the same as the Event Hub Location",
				"strongType": "location"
			}
		},
  "effect": {
    "type": "String",
    "defaultValue": "DeployIfNotExists",
    "allowedValues": [
      "DeployIfNotExists",
      "Disabled"
    ],
    "metadata": {
      "displayName": "Effect",
      "description": "Enable or disable the execution of the policy"
    }
  },
   "profileName": {
    "type": "String",
    "defaultValue": "diag-logs-eh",
    "metadata": {
      "displayName": "Profile name",
      "description": "The diagnostic settings profile name"
    }
  },
  "logsEnabled": {
    "type": "String",
    "defaultValue": "True",
    "allowedValues": [
      "True",
      "False"
    ],
    "metadata": {
      "displayName": "Enable logs",
      "description": "Whether to enable logs stream to the Eventhub - True or False"
    }
  }
}

PARAMETERS


  policy_rule = <<POLICY_RULE

{
  "if": {
    "field": "type",
    "equals": "Microsoft.Databricks/workspaces"
  },
  "then": {
    "effect": "[parameters('effect')]",
    "details": {
      "type": "Microsoft.Insights/diagnosticSettings",
      "name": "[parameters('profileName')]",
      "existenceCondition": {
        "allOf": [
          {
            "field": "Microsoft.Insights/diagnosticSettings/logs.enabled",
            "equals": "true"
          },
          {
			 "field": "Microsoft.Insights/diagnosticSettings/eventHubAuthorizationRuleId",
			 "matchInsensitively": "[parameters('eventHubAuthorizationRuleId')]"
		  },
          {
			 "field": "location",
			 "equals": "[parameters('Location')]"
		  }
        ]
      },
      "roleDefinitionIds": [
        "/providers/microsoft.authorization/roleDefinitions/749f88d5-cbae-40b8-bcfc-e573ddc772fa",
        "/providers/microsoft.authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293"
      ],
      "deployment": {
        "properties": {
          "mode": "Incremental",
          "template": {
            "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
            "contentVersion": "1.0.0.0",
            "parameters": {
              "resourceName": {
                "type": "String"
              },
              "location": {
                "type": "String"
              },
              "eventHubAuthorizationRuleId": {
                 "type": "string"
              },
               "profileName": {
                "type": "String"
              },
              "logsEnabled": {
                "type": "String"
              }
            },
            "variables": {},
            "resources": [
              {
                "type": "Microsoft.Databricks/workspaces/providers/diagnosticSettings",
                "apiVersion": "2017-05-01-preview",
                "name": "[concat(parameters('resourceName'), '/', 'Microsoft.Insights/', parameters('profileName'))]",
                "location": "[parameters('location')]",
                "dependsOn": [],
                "properties": {
                  "eventHubAuthorizationRuleId": "[parameters('eventHubAuthorizationRuleId')]",
                  "logs": [
                      {
                        "category": "dbfs",
                        "enabled": "[parameters('logsEnabled')]"
                      },
                      {
                        "category": "clusters",
                        "enabled": "[parameters('logsEnabled')]"
                      },
                      {
                        "category": "accounts",
                        "enabled": "[parameters('logsEnabled')]"
                      },
                      {
                        "category": "jobs",
                        "enabled": "[parameters('logsEnabled')]"
                      },
                      {
                        "category": "notebook",
                        "enabled": "[parameters('logsEnabled')]"
                      },
                      {
                        "category": "ssh",
                        "enabled": "[parameters('logsEnabled')]"
                      },
                      {
                        "category": "workspace",
                        "enabled": "[parameters('logsEnabled')]"
                      },
                      {
                        "category": "secrets",
                        "enabled": "[parameters('logsEnabled')]"
                      },
                      {
                        "category": "sqlPermissions",
                        "enabled": "[parameters('logsEnabled')]"
                      },
                      {
                        "category": "instancePools",
                        "enabled": "[parameters('logsEnabled')]"
                      }
                  ]
                }
              }
            ],
            "outputs": {}
          },
          "parameters": {
            "eventHubAuthorizationRuleId": {
              "value": "[parameters('eventHubAuthorizationRuleId')]"
            },
            "Location": {
              "value": "[field('location')]"
            },
            "resourceName": {
              "value": "[field('name')]"
            },
            "profileName": {
              "value": "[parameters('profileName')]"
            },
            "logsEnabled": {
              "value": "[parameters('logsEnabled')]"
            }
          }
        }
      }
    }
  }
}
POLICY_RULE
}

data "azurerm_subscription" "current" {}

resource "azurerm_subscription_policy_assignment" "assign_policy" {
  name                 = "policy-assignment-databricks-event"
  policy_definition_id = azurerm_policy_definition.storage_diaglogs.id
  subscription_id      = data.azurerm_subscription.current.id
  location             = "eastus2"
  parameters           = <<PARAMETERS
    {
      "eventHubAuthorizationRuleId": {
        "value": "/subscriptions/f3d20c9f-3cb5-45df-b6a8-32f7f4e3d1b6/resourcegroups/sample-1/providers/Microsoft.EventHub/namespaces/myeventhubankurcentra/authorizationrules/RootManageSharedAccessKey"
      },
	     "Location": {
        "value": "centralus"
      }
    }
  PARAMETERS

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.mi-cloudops-azpolicy.id]

  }

}

