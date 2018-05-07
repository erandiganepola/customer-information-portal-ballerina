//
// Copyright (c) 2018, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//

@final string QUERY_TO_GET_JIRA_KEYS_FROM_RECORD_STATUS_TABLE =
"SELECT jira_key FROM 'RecordStatus'";

@final string QUERY_TEMPLATE_GET_OPPORTUNITY_IDS_BY_JIRA_KEYS =
"SELECT opportunity_id FROM SupportAccount WHERE jira_key in <JIRA_KEY_LIST>";

@final string QUERY_TEMPLATE_GET_OPPORTUNITY_IDS_TO_BE_DELETED =
"SELECT opportunity_id FROM SupportAccount WHERE opportunity_id IN <IDS> GROUP BY opportunity_id
HAVING count(opportunity_id)=1";

@final string QUERY_TEMPLATE_GET_ACCOUNT_IDS_BY_OPPORTUNITY_IDS =
"SELECT account_id FROM Opportunity WHERE opportunity_id IN <IDS>";

@final string QUERY_TEMPLATE_GET_ACCOUNT_IDS_TO_BE_DELETED =
"SELECT account_id FROM Opportunity WHERE account_id IN <IDS> GROUP BY account_id
HAVING count(account_id)=1";

@final string QUERY_TEMPLATE_DELETE_FROM_SUPPORT_ACCOUNT_BY_JIRA_KEYS =
"DELETE FROM SupportAccount where jira_key IN <JIRA_KEY_LIST>";

@final string QUERY_TEMPLATE_DELETE_FROM_ACCOUNT_BY_ACCOUNT_IDS =
"DELETE FROM Account WHERE account_id IN <IDS>";

@final string QUERY_TEMPLATE_DELETE_FROM_OPPORTUNITY_BY_OPPORTUNITY_IDS =
"DELETE FROM Opportunity WHERE opportunity_id IN <IDS>";

@final string QUERY_TEMPLATE_DELETE_FROM_OPPORTUNITY_PRODUCT_BY_IDS =
"DELETE FROM OpportunityProducts WHERE opportunity_id IN <IDS>;";

@final string QUERY_TO_INSERT_VALUES_TO_OPPORTUNITY_PRODUCTS =
"INSERT INTO Opportunity_Products (JIRA_key, Product_name, Profile, Count, Deployment)
VALUES
   (?,?,?,?,?)
ON DUPLICATE KEY UPDATE
    JIRA_key = VALUES(JIRA_key),
    Product_name = VALUES(Product_name),
    Profile = VALUES(Profile),
    Count = VALUES(Count),
    Deployment = 'PROD'";

@final string QUERY_TO_INSERT_VALUES_TO_ACCOUNT =
"INSERT INTO Account (JIRA_key, Customer_name, Customer_type, Classification, Account_owner,
                  Technical_owner, Domain, Primary_contact, Timezone)
VALUES
   (?,?,?,?,?,?,?,?,?)
ON DUPLICATE KEY UPDATE
   JIRA_key = VALUES(JIRA_key),
   Customer_name = VALUES(Customer_name),
   Customer_type = VALUES(Customer_type),
   Classification = VALUES(Classification),
   Account_owner = VALUES(Account_owner),
   Technical_owner = 'Nuwan',
   Domain = VALUES(Domain),
   Primary_contact = VALUES(Primary_contact),
   Timezone = VALUES(Timezone)";