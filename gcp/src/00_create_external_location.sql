-- Create the storage credential 'gcp-billing-cred' ahead of time. This script needs to be run only once
CREATE EXTERNAL LOCATION gcp_billing_location
URL '${source_file_path}'
WITH (STORAGE CREDENTIAL `gcp-billing-cred` 
);