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

import ballerina/log;
import ballerina/sql;
import ballerina/io;

function organizeSfData(json[] records) returns map {
    map<json[]> sfDataMap;
    foreach record in records {
        string jiraKey = record["Support_Accounts__r"]["records"][0]["JIRA_Key__c"].toString();
        if (jiraKey == () || jiraKey == "null") {
            io:println(record["Support_Accounts__r"]);
        }

        json opportunity = {
            "Id": record["Id"],
            "Account": {
                "Id": record["Account"]["Id"],
                "Name": record["Account"]["Name"],
                "Classification": record["Account"]["Account_Classification__c"],
                "Owner": record["Account"]["Owner"]["Name"],
                "Rating": record["Account"]["Rating"],
                "TechnicalOwner": record["Account"]["Technical_Owner__c"],
                "Industry": record["Account"]["Industry"],
                "Phone": record["Account"]["Phone"],
                "BillingAddress": record["Account"]["BillingAddress"]
            },
            "SupportAccount": {
                "Id": record["Support_Accounts__r"]["records"][0]["Id"],
                "JiraKey": record["Support_Accounts__r"]["records"][0]["JIRA_Key__c"],
                "StartDate": record["Support_Accounts__r"]["records"][0]["Start_Date__c"],
                "EndDate": record["Support_Accounts__r"]["records"][0]["End_Date__c"]
            },
            "OpportunityLineItems": []
        };

        if (record["OpportunityLineItems"]["records"] != null){
            foreach item in record["OpportunityLineItems"]["records"] {
                json lineItem = {
                    "Id": item["Id"],
                    "Quantity": item["Quantity"],
                    "Environment": item["Environment__c"],
                    "Product": item["PricebookEntry"]["Name"]
                };

                opportunity["OpportunityLineItems"][lengthof opportunity["OpportunityLineItems"]] = lineItem;
            }
        }

        if (!sfDataMap.hasKey(jiraKey)) {
            log:printDebug("Adding new Jira key: " + jiraKey);
            sfDataMap[jiraKey] = [opportunity];
        } else {
            log:printDebug("Adding data for existing Jira key: " + jiraKey);
            int index = (lengthof sfDataMap[jiraKey]);

            sfDataMap[jiraKey][index] = opportunity;
        }
    }
    return sfDataMap;
}

//=================================================================================================//
function getJiraKeysFromJira() returns string[]|error {
    //Get JIRA keys from JIRA API
    http:Request httpRequest = new;
    var jiraResponse = httpClientEP->get("/collector/jira/keys", request = httpRequest);
    match jiraResponse {
        http:Response resp => {
            json jsonResponse = resp.getJsonPayload() but {
                error e => log:printError("Error occurred while receiving Json payload. Error: " + e.message)
            };

            log:printDebug("Received JIRA keys response: " + jsonResponse.toString());
            return <string[]>jsonResponse;
        }
        error e => {
            log:printError("Failed to fetch JIRA keys from JIRA API. Error: " + e.message);
            return e;
        }
    }
}

function getJiraKeysFromDB() returns string[]|error {
    //Get JIRA keys from Salesforce RecordStatus DB table
    var selectResults = mysqlEP->select(QUERY_TO_GET_JIRA_KEYS_FROM_RECORD_STATUS_TABLE, ());
    match selectResults {
        table tableReturned => {
            // TODO: Get JIRA keys from table
            string[] results;
            return results;

        }
        error e => {
            log:printError("<SELECT jira_key FROM RecordStatus> failed! Error: " + e.message);
            return e;
        }
    }
}

function upsertRecordStatus(string[] jiraKeys) returns boolean {
    log:printDebug("Upserting " + lengthof jiraKeys + "");
    string values = "";
    foreach key in jiraKeys {
        values += string `,('{{key}}', NULL)`;
    }

    values = values.replaceFirst(",", "");

    string q = QUERY_BULK_UPSERT_RECORD_STATUS.replace("<ENTRIES>", values);
    log:printDebug("Record status bulk update: " + q);
    var results = mysqlEP->update(q);
    match results {
        int c => {
            log:printInfo(string `Inserted {{lengthof jiraKeys}} jira keys. Return value {{c}}`);
            return c >= 0;
        }
        error e => {
            log:printError("Unable to insert record status", err = e);
            return false;
        }
    }

    // TODO check whether all those keys were inserted with NULL completed_time
}

//=================================================================================================//
// Upsert data into Salesforce database tables
function upsertDataIntoSfDb(map organizedDataMap) {
    foreach key, value in organizedDataMap{
        log:printDebug("\n");
        log:printInfo("Upserting transaction starting for jira key : " + key);
        //Start transaction
        transaction with retries = 3, oncommit = onUpsertCommitFunction, onabort = onUpsertAbortFunction {
        // TODO lock record status row
        // TODO get the batch_id from batch_status table and check if that's equal to mine

            foreach opportunity in check <json[]>value {
                //Inserting to Account table
                var accountResult = mysqlEP->update(QUERY_TO_INSERT_VALUES_TO_ACCOUNT,
                    opportunity["Account"]["Id"].toString(),
                    opportunity["Account"]["Name"].toString(),
                    opportunity["Account"]["Classification"].toString(),
                    opportunity["Account"]["Rating"].toString(),
                    opportunity["Account"]["Owner"].toString(),
                    opportunity["Account"]["TechnicalOwner"].toString(),
                    opportunity["Account"]["Industry"].toString(),
                    opportunity["Account"]["Phone"].toString(),
                    opportunity["Account"]["BillingAddress"]["city"].toString(),
                    opportunity["Account"]["BillingAddress"]["country"].toString(),
                    opportunity["Account"]["BillingAddress"]["geocodeAccuracy"].toString(),
                    opportunity["Account"]["BillingAddress"]["latitude"].toString(),
                    opportunity["Account"]["BillingAddress"]["longitude"].toString(),
                    opportunity["Account"]["BillingAddress"]["postalCode"].toString(),
                    opportunity["Account"]["BillingAddress"]["state"].toString(),
                    opportunity["Account"]["BillingAddress"]["street"].toString());

                match accountResult {
                    int c => {
                        if (c < 0) {
                            log:printError("Unable to insert account for jira key: " + key);
                            abort;
                        } else {
                            log:printDebug("Inserted new row to Account");
                        }
                    }
                    error e => {
                        retry;
                    }
                }

                //Inserting to Opportunity table
                var oppResult = mysqlEP->update(QUERY_TO_INSERT_VALUES_TO_OPPORTUNITY,
                    opportunity["Id"].toString(),
                    opportunity["Account"]["Id"].toString());
                match oppResult {
                    int c => {
                        if (c < 0) {
                            log:printError("Unable to insert opportunity for jira key: " + key);
                            abort;
                        } else {
                            log:printDebug("Inserted new row to Opportunity");
                        }
                    }
                    error e => {
                        retry;
                    }
                }

                //Inserting to OpportunityProducts table
                log:printDebug(string `Inserting {{lengthof opportunity["OpportunityLineItems"]}} OpportunityProducts`);
                foreach lineItem in opportunity["OpportunityLineItems"] {
                    var lineItemsResult = mysqlEP->update(QUERY_TO_INSERT_VALUES_TO_OPPORTUNITY_PRODUCTS,
                        lineItem["Id"].toString(), opportunity["Id"].toString(), lineItem["Product"].toString(),
                        lineItem["Product"].toString(), lineItem["Quantity"].toString(),
                        lineItem["Environment"].toString());

                    match lineItemsResult {
                        int c => {
                            if (c < 0) {
                                log:printError("Unable to insert opportunity product: " + lineItem.toString());
                                abort;
                            }
                        }
                        error e => {
                            retry;
                        }
                    }
                }
                log:printDebug("Inserted opportunity products");

                //Inserting to SupportAccount table
                sql:Parameter startDate = {
                    sqlType: sql:TYPE_DATE,
                    value: null
                };

                sql:Parameter endDate = {
                    sqlType: sql:TYPE_DATE,
                    value: null
                };

                if (opportunity["SupportAccount"]["StartDate"] != ()){
                    startDate = {
                        sqlType: sql:TYPE_DATE,
                        value: opportunity["SupportAccount"]["StartDate"].toString()
                    };
                }

                if (opportunity["SupportAccount"]["EndDate"] != ()){
                    endDate = {
                        sqlType: sql:TYPE_DATE,
                        value: opportunity["SupportAccount"]["EndDate"].toString()
                    };
                }
                var supportAccResult = mysqlEP->update(QUERY_TO_INSERT_VALUES_TO_SUPPORT_ACCOUNT,
                    opportunity["SupportAccount"]["Id"].toString(), opportunity["Id"].toString(),
                    opportunity["SupportAccount"]["JiraKey"].toString(), startDate, endDate);
                match supportAccResult {
                    int c => {
                        if (c < 0) {
                            log:printError("Unable to insert support account for jira key: " + key);
                            abort;
                        } else {
                            log:printDebug("Inserted new row to SupportAccount");
                        }
                    }
                    error e => {
                        //log:printError("Error ", err=e);
                        retry;
                    }
                }
            }

            log:printDebug("All done for Jira key " + key + ". Updating record status");
            var result = mysqlEP->update(QUERY_UPDATE_RECORD_STATUS, key);
            match result {
                int c => {
                    if (c < 0) {
                        log:printError("Unable to update record status for jira key: " + key);
                        abort;
                    } else {
                        log:printDebug("Updated record status for jira key: " + key);
                    }
                }
                error e => {
                    retry;
                }
            }
        }
        onretry {
            log:printWarn("Retrying transaction...");
        }
    }
}


function onUpsertCommitFunction(string transactionId) {
    log:printInfo("Successful! Upsertion transaction comitted with transaction ID: " + transactionId);
}

function onUpsertAbortFunction(string transactionId) {
    log:printInfo("Failed! Upsertion transaction aborted with transaction ID: " + transactionId);
}

//================================================================================================//

public function buildQueryFromTemplate(string template, json|string[] jiraKeys) returns string {
    string key_tuple = EMPTY_STRING;
    match jiraKeys {
        json jsonJiraKeys => {
            foreach key in jsonJiraKeys{
                key_tuple += "," + "'" + key.toString() + "'";
            }
        }

        string[] stringJiraKeys => {
            foreach key in stringJiraKeys{
                key_tuple += "," + "'" + key + "'";
            }
        }
    }
    key_tuple = key_tuple.replaceFirst(",", "");
    key_tuple = "(" + key_tuple + ")";

    string resultQuery = template.replace("<JIRA_KEY_LIST>", key_tuple);
    //io:println(resultQuery);
    return resultQuery;
}

public function categorizeJiraKeys(string[] newKeys, string[] currentKeys) returns map {
    string[] toBeUpserted = [];
    string[] toBeDeleted = [];
    int i_upsert = 0;
    int i_delete = 0;

    foreach (key in newKeys){
        toBeUpserted[i_upsert] = key;
        i_upsert += 1;
    }

    foreach (key in currentKeys){
        if (!hasJiraKey(newKeys, key)){ //update
            toBeDeleted[i_delete] = key;
            i_delete += 1;
        }
    }
    map result = { "toBeUpserted": toBeUpserted, "toBeDeleted": toBeDeleted };
    return result;
}

function hasJiraKey(string[] list, string key) returns boolean {
    foreach (item in list){
        if (item == key){
            return true;
        }
    }
    return false;
}

//TODO: Remove delete functionality
//=================================================================================================//
//Delete Jira keys from Salesforce database if those not exist in Jira

function deleteJiraKeys(string[] jiraKeysToBeDeleted) {
    string[] oppIds;
    string[] oppIdsToBeDeleted;
    string[] accountIds;
    string[] accountIdsToBeDeleted;

    log:printDebug("Starting transaction: deleting records from Salesforce DB...");
    transaction with retries = 4, oncommit = onDeleteCommitFunction, onabort = onDeleteAbortFunction {
    // Get JIRA keys from SF DB, RecordStatus table
        var selectResultsJiraKeys = mysqlEP->select(QUERY_TO_GET_JIRA_KEYS_FROM_RECORD_STATUS_TABLE, ());
        match selectResultsJiraKeys {
            table tableReturned => {
                io:println(tableReturned);
            }
            error err => {
                log:printError("SELECT query failed! Error: " + err.message);
            }
        }

        // Get Opportunity Ids by jira keys
        var selectResultsOppIds = mysqlEP->select(dc:buildQueryFromTemplate(
                                                      QUERY_TEMPLATE_GET_OPPORTUNITY_IDS_BY_JIRA_KEYS,
                                                      jiraKeysToBeDeleted), ());
        match selectResultsOppIds {
            table tableReturned => {
                io:println(tableReturned);
                string[] oppIds;
            }
            error err => {
                log:printError("SELECT query failed! Error: " + err.message);
            }
        }

        // Out of those Opportunity Ids, find which are not used in other Support Accounts to be deleted
        var selectResultsOppIdsToDelete = mysqlEP->select(dc:buildQueryFromTemplate(
                                                              QUERY_TEMPLATE_GET_OPPORTUNITY_IDS_TO_BE_DELETED, oppIds),
            ());
        match selectResultsOppIdsToDelete {
            table tableReturned => {
                io:println(tableReturned);
                string[] oppIdsToBeDeleted;
            }
            error err => {
                log:printError("SELECT query failed! Error: " + err.message);
            }
        }

        // Get Account Ids by Opportunity Ids
        var selectResultsAccIds = mysqlEP->select(dc:buildQueryFromTemplate(
                                                      QUERY_TEMPLATE_GET_ACCOUNT_IDS_BY_OPPORTUNITY_IDS,
                                                      oppIdsToBeDeleted), ());
        match selectResultsAccIds {
            table tableReturned => {
                io:println(tableReturned);
                string[] accountIds;
            }
            error err => {
                log:printError("SELECT query failed! Error: " + err.message);
            }
        }

        // Get Account Ids to be deleted
        var selectResultsAccIdsToDelete = mysqlEP->select(dc:buildQueryFromTemplate(
                                                              QUERY_TEMPLATE_GET_ACCOUNT_IDS_TO_BE_DELETED, accountIds),
            ());
        match selectResultsAccIdsToDelete {
            table tableReturned => {
                io:println(tableReturned);
                string[] accountIdsToBeDeleted;
            }
            error err => {
                log:printError("SELECT query failed! Error: " + err.message);
            }
        }

        var result = mysqlEP->update(dc:buildQueryFromTemplate
            (QUERY_TEMPLATE_DELETE_FROM_SUPPORT_ACCOUNT_BY_JIRA_KEYS, jiraKeysToBeDeleted));

        result = mysqlEP->update(dc:buildQueryFromTemplate
            (QUERY_TEMPLATE_DELETE_FROM_ACCOUNT_BY_ACCOUNT_IDS, accountIdsToBeDeleted));

        result = mysqlEP->update(dc:buildQueryFromTemplate
            (QUERY_TEMPLATE_DELETE_FROM_OPPORTUNITY_BY_OPPORTUNITY_IDS, oppIdsToBeDeleted));

        // Can do this with "ON DELETE CASCADE"
        result = mysqlEP->update(dc:buildQueryFromTemplate
            (QUERY_TEMPLATE_DELETE_FROM_OPPORTUNITY_PRODUCT_BY_IDS, oppIdsToBeDeleted));

        //TODO: Update BatchStatus table with deletion_completed_time

        match result {
            int c => {
                log:printDebug("Deletion transaction completed successfully!!");
                // The transaction can be force aborted using the `abort` keyword at any time.
                if (c == 0) {
                    abort;
                }
            }
            error e => {
                retry;
            }
        }
    } onretry {
        io:println("Retrying transaction");
    }
}

function onDeleteCommitFunction(string transactionId) {
    log:printDebug("Successful! Upsertion transaction comitted with transaction ID: " + transactionId);
}

function onDeleteAbortFunction(string transactionId) {
    log:printDebug("Failed! Upserting transaction aborted with transaction ID: " + transactionId);
}

function handleDeletionError(string message, error e, mysql:Client testDB) {
    log:printError("Error occured during deletion. Error: " + e.message);
    io:println(message + e.message);
}
