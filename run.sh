az login --tenant 9f37a392-f0ae-4280-9796-f1864a10effc
az account set --subscription 3f2e4d32-8e8d-46d6-82bc-5bb8d962328b
terraform validate
terraform plan 
# terrform apply
# terraform import azurerm_databricks_workspace.brn-c-adb-rfc6598-ws /subscriptions/3f2e4d32-8e8d-46d6-82bc-5bb8d962328b/resourceGroups/brn-ip-conserve/providers/Microsoft.Databricks/workspaces/brn-c-adb-rfc6598-ws
