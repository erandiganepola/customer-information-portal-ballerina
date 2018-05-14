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

@final string QUERY_GET_BATCH_STATUS_WITH_LOCK =
"SELECT uuid, state, completed_time FROM BatchStatus LIMIT 1 FOR UPDATE";

@final string QUERY_GET_BATCH_STATUS = "SELECT uuid, state, completed_time FROM BatchStatus LIMIT 1";

@final string QUERY_SET_BATCH_STATUS = "UPDATE BatchStatus SET uuid=?, state=?, completed_time=now()";
@final string QUERY_INSERT_BATCH_STATUS = "INSERT INTO BatchStatus(uuid, state, completed_time) VALUES(?,?,now())";

@final string QUERY_SET_BATCH_UUID = "UPDATE BatchStatus SET uuid=?";

@final string QUERY_GET_INCOMPLETE_JIRA_KEYS = "SELECT jira_key FROM RecordStatus WHERE
completed_time IS NULL";

@final string QUERY_CLEAR_RECORD_STATUS_TABLE = "TRUNCATE TABLE RecordStatus";

@final string QUERY_INCOMPLETE_RECORD_COUNT =
"SELECT COUNT(jira_key) as c FROM RecordStatus WHERE jira_key IN (<JIRA_KEY_LIST>) AND completed_time IS NULL";

@final string QUERY_BULK_UPSERT_RECORD_STATUS = "INSERT INTO RecordStatus(jira_key, completed_time)
VALUES <ENTRIES>
ON DUPLICATE KEY UPDATE
    jira_key = VALUES(jira_key),
    completed_time = NULL";

@final string QUERY_UPDATE_RECORD_STATUS = "UPDATE RecordStatus SET completed_time=now() WHERE jira_key=?";

@final string QUERY_TO_GET_JIRA_KEYS_FROM_RECORD_STATUS_TABLE =
"SELECT jira_key FROM RecordStatus";

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

@final string QUERY_TO_INSERT_VALUES_TO_ACCOUNT =
"INSERT INTO Account (account_id, customer_name, customer_type, classification, account_owner,
                  technical_owner, domain, primary_contact, city, country, geocode_accuracy,
                  latitude, longitude, postal_code, state, street)
VALUES
   (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
ON DUPLICATE KEY UPDATE
   account_id = VALUES(account_id),
   customer_name = VALUES(customer_name),
   customer_type = VALUES(customer_type),
   classification = VALUES(classification),
   account_owner = VALUES(account_owner),
   technical_owner = VALUES(technical_owner),
   domain = VALUES(domain),
   primary_contact = VALUES(primary_contact),
   city = VALUES(city),
   country = VALUES(country),
   geocode_accuracy = VALUES(geocode_accuracy),
   latitude = VALUES(latitude),
   longitude = VALUES(longitude),
   postal_code = VALUES(postal_code),
   state = VALUES(state),
   street = VALUES(street)";

@final string QUERY_TO_INSERT_VALUES_TO_OPPORTUNITY =
"INSERT INTO Opportunity (opportunity_id, account_id)
VALUES
   (?,?)
ON DUPLICATE KEY UPDATE
   opportunity_id = VALUES(opportunity_id),
   account_id = VALUES(account_id)";

@final string QUERY_TO_INSERT_VALUES_TO_OPPORTUNITY_PRODUCTS =
"INSERT INTO OpportunityProducts (opportunity_product_id, opportunity_id, name, profile, count, deployment)
VALUES
   (?,?,?,?,?,?)
ON DUPLICATE KEY UPDATE
    opportunity_product_id = VALUES(opportunity_product_id),
    opportunity_id = VALUES(opportunity_id),
    name = VALUES(name),
    profile = VALUES(profile),
    count = VALUES(count),
    deployment = VALUES(deployment)";

@final string QUERY_TO_INSERT_VALUES_TO_SUPPORT_ACCOUNT =
"INSERT INTO SupportAccount (support_account_id, opportunity_id, jira_key, start_date, end_date)
VALUES
   (?,?,?,?,?)
ON DUPLICATE KEY UPDATE
    support_account_id = VALUES(support_account_id),
    opportunity_id = VALUES(opportunity_id),
    jira_key = VALUES(jira_key),
    start_date = VALUES(start_date),
    end_date = VALUES(end_date)";

@final string QUERY_TO_INSERT_VALUES_TO_BATCH_STATUS =
"INSERT INTO Opportunity_Products (id, state, deletion_completed_time, sync_completed_time, uuid)
VALUES
   (?,?,?,?,?)
ON DUPLICATE KEY UPDATE
    id = VALUES(id),
    state = VALUES(state),
    deletion_completed_time = VALUES(deletion_completed_time),
    sync_completed_time = VALUES(sync_completion_time),
    uuid = VALUES(uuid)";

@final string QUERY_TO_INSERT_VALUES_TO_RECORD_STATUS =
"INSERT INTO Opportunity_Products (jira_key, completed_time)
VALUES
   (?,?)
ON DUPLICATE KEY UPDATE
    jira_key = VALUES(jira_key),
    completed_time = VALUES(completed_time)";
