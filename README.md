# Cloud Infra Costs 
For Databricks non-serverless compute, total cost of ownership (TCO) information is fragmented between cloud cost reports (e.g., AWS CUR, Azure Cost Mgmt) & Databricks system tables (richer granularity & metadata). While many users are becoming increasingly familiar with Databricks system tables, joining with Azure & AWS cost reports can be cumbersome.

This solution helps automate and simplify this process - with it, users can report on the total infra (VM, networking, storage) and Databricks costs (DBUs) of their classic compute, in unified dashboards.

The solution is broken down into two pieces.  One for Azure Databricks customers and the other for customers deploying Databricks on AWS.  For instructions on how to setup this solution, please see the following:
- [Azure](azure/README.md)
- [AWS](aws/README.md)

<img width="1444" height="653" alt="Screenshot 2025-11-05 at 10 58 37 AM" src="https://github.com/user-attachments/assets/611b8cf5-cf23-4c98-84a9-eab3776669fe" />


## How to get help

Databricks support doesn't cover this content. For questions or bugs, please open a GitHub issue and the team will help on a best effort basis.


## License

&copy; 2025 Databricks, Inc. All rights reserved. The source in this notebook is provided subject to the Databricks License [https://databricks.com/db-license-source].  All included or referenced third party libraries are subject to the licenses set forth below.

| library                                | description             | license    | source                                              |
|----------------------------------------|-------------------------|------------|-----------------------------------------------------|
| HashiCorp Terraform                    | Infrastructure as code tool | [BUSL 1.1](https://www.hashicorp.com/bsl)   | https://github.com/hashicorp/terraform              |
| hashicorp/azurerm Terraform provider   | Azure Resource Manager provider for Terraform | [MPL 2.0](https://www.mozilla.org/en-US/MPL/2.0/)    | https://github.com/hashicorp/terraform-provider-azurerm |
| databricks/databricks Terraform provider | Databricks provider for Terraform | [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) | https://github.com/databricks/terraform-provider-databricks |
| Apache Spark (PySpark)                 | Distributed data processing engine (runtime dependency) | [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) | https://github.com/apache/spark                     |
