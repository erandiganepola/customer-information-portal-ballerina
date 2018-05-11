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

import ballerina/io;

function organizeSfData(json resultFromSf) returns map {
    json[] records = check <json[]>resultFromSf.records;
    map<json[]> sfDataMap;

    foreach record in records {
        string jiraKey = record["Support_Accounts__r"]["records"][0]["JIRA_Key__c"].toString();
        io:println(jiraKey);

        json opportunity = {
            "Id": record["Id"],
            "Account": {
                "Id": record["Account"]["Id"],
                "Name": record["Account"]["Name"],
                "Classification": record["Account"]["Account_Classification__c"],
                "Owner": record["Account"]["Owner"]["Name"],
                "Rating": record["Account"]["Rating"]["Name"],
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

            if(record["OpportunityLineItems"]["records"] != null){
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
            io:println("Adding key: " + jiraKey);
            sfDataMap[jiraKey] = [opportunity];
        } else {
            io:println("Has jira key: " + jiraKey);
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
    var out = httpClientEP->get("/collector/jira/keys", request = httpRequest);
    match out {
        http:Response resp => {
            io:println(resp.getJsonPayload());
            return check <string[]>check resp.getJsonPayload();
        }
        error err => {
            log:printError("Failed to fetch JIRA keys from JIRA API. Error: " + err.message);
            return err;
        }
    }
}

function getJiraKeysFromDB() returns string[]|error {
    //Get JIRA keys from Salesforce RecordStatus DB table
    var selectResults = mysqlEP->select(QUERY_TO_GET_JIRA_KEYS_FROM_RECORD_STATUS_TABLE, ());
    match selectResults {
        table tableReturned => {
            io:println(tableReturned);
            // TODO: Get JIRA keys from table
            string[] results;
            return results;

        }
        error err => {
            log:printError("<SELECT jira_key FROM 'RecordStatus'> failed! Error: " + err.message);
            return err;
        }
    }
}

//=================================================================================================//
//Delete Jira keys from Salesforce database if those not exist in Jira

function deleteJiraKeys(string[] jiraKeysToBeDeleted) {
    string[] oppIds;
    string[] oppIdsToBeDeleted;
    string[] accountIds;
    string[] accountIdsToBeDeleted;

    log:printDebug("Starting transaction: deleting records from Salesforce DB...");
    transaction with retries = 4, oncommit = onCommitFunction, onabort = onAbortFunction {
        // Get JIRA keys from SF DB, RecordStatus table
        var selectResultsJiraKeys = mysqlEP -> select(QUERY_TO_GET_JIRA_KEYS_FROM_RECORD_STATUS_TABLE, ());
            match selectResultsJiraKeys {
                table tableReturned => {
                    io:println(tableReturned);
                }
                error err => {
                    log:printError("SELECT query failed! Error: " + err.message);
                }
        }

        // Get Opportunity Ids by jira keys
        var selectResultsOppIds = mysqlEP -> select(dc:buildQueryFromTemplate(
        QUERY_TEMPLATE_GET_OPPORTUNITY_IDS_BY_JIRA_KEYS, jiraKeysToBeDeleted), ());
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
        var selectResultsOppIdsToDelete = mysqlEP -> select(dc:buildQueryFromTemplate(
        QUERY_TEMPLATE_GET_OPPORTUNITY_IDS_TO_BE_DELETED, oppIds), ());
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
        var selectResultsAccIds = mysqlEP -> select(dc:buildQueryFromTemplate(
        QUERY_TEMPLATE_GET_ACCOUNT_IDS_BY_OPPORTUNITY_IDS, oppIdsToBeDeleted), ());
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
        var selectResultsAccIdsToDelete = mysqlEP -> select(dc:buildQueryFromTemplate(
        QUERY_TEMPLATE_GET_ACCOUNT_IDS_TO_BE_DELETED, accountIds), ());
        match selectResultsAccIdsToDelete {
            table tableReturned => {
                io:println(tableReturned);
                string[] accountIdsToBeDeleted;
            }
            error err => {
                log:printError("SELECT query failed! Error: " + err.message);
            }
        }

        var result = mysqlEP -> update(dc:buildQueryFromTemplate
        (QUERY_TEMPLATE_DELETE_FROM_SUPPORT_ACCOUNT_BY_JIRA_KEYS, jiraKeysToBeDeleted));

        result = mysqlEP -> update(dc:buildQueryFromTemplate
        (QUERY_TEMPLATE_DELETE_FROM_ACCOUNT_BY_ACCOUNT_IDS, accountIdsToBeDeleted));

        result = mysqlEP -> update(dc:buildQueryFromTemplate
        (QUERY_TEMPLATE_DELETE_FROM_OPPORTUNITY_BY_OPPORTUNITY_IDS, oppIdsToBeDeleted));

        // Can do this with "ON DELETE CASCADE"
        result = mysqlEP -> update(dc:buildQueryFromTemplate
        (QUERY_TEMPLATE_DELETE_FROM_OPPORTUNITY_PRODUCT_BY_IDS, oppIdsToBeDeleted));

        //TODO: Update BatchStatus table deletion_completed_time

        match result {
            int c => {
                log:printDebug("Deletion transaction completed successfully!!");

                // The transaction can be force aborted using the `abort` keyword at any time.
                if (c == 0) {
                    abort;
                }
            }
            error err => {
                // The transaction can be force retried using `retry` keyword at any time.
                io:println(err);
                retry;
            }
        }
    } onretry {
        io:println("Retrying transaction");
    }
}

//=================================================================================================//
// Upsert data into Salesforce database tables

function upsertDataIntoSfDb(map organizedDataMap){
    foreach upsertKey in organizedDataMap {
        transaction with retries =3, oncommit = onCommitFunction, onabort = onAbortFunction {
            log:printInfo("Upsertion transaction starting...");
            foreach key, value in organizedDataMap{
            //Start transaction
                foreach opportunity in check <json[]>value{

                string billingAddress =
                    opportunity["Account"]["BillingAddress"]["city"].toString() + " " +
                    opportunity["Account"]["BillingAddress"]["country"].toString() + " " +
                    opportunity["Account"]["BillingAddress"]["geocodeAccuracy"].toString() + " " +
                    opportunity["Account"]["BillingAddress"]["latitude"].toString() + " " +
                    opportunity["Account"]["BillingAddress"]["longitude"].toString() + " " +
                    opportunity["Account"]["BillingAddress"]["postalCode"].toString() + " " +
                    opportunity["Account"]["BillingAddress"]["state"].toString() + " " +
                    opportunity["Account"]["BillingAddress"]["street"].toString();

                //Inserting to Account table
                var accountResult = mysqlEP -> update(QUERY_TO_INSERT_VALUES_TO_ACCOUNT,
                opportunity["Account"]["Id"].toString(), opportunity["Account"]["Name"].toString(),
                opportunity["Account"]["Classification"].toString(), opportunity["Account"]["Rating"].toString(),
                opportunity["Account"]["Owner"].toString(), opportunity["Account"]["TechnicalOwner"].toString(),
                opportunity["Account"]["Industry"].toString(), opportunity["Account"]["Phone"].toString(),
                billingAddress);
                // todo Make billling address flat -> add more columns to table (city, street, etc.)
                match accountResult {
                    int c => {
                        io:println("Inserted count: " + c);
                        // The transaction can be force aborted using the `abort` keyword at any time.
                        if (c == 0) {
                            abort;
                        }
                    }
                    error err => {
                         //The transaction can be force retried using `retry` keyword at any time.
                        io:println(err);
                        retry;
                    }
                }

                //Inserting to Opportunity table
                var oppResult = mysqlEP -> update(QUERY_TO_INSERT_VALUES_TO_OPPORTUNITY,
                opportunity["Id"].toString(),
                opportunity["Account"]["Id"].toString());
                match oppResult {
                    int c => {
                        io:println("Inserted count: " + c);
                        // The transaction can be force aborted using the `abort` keyword at any time.
                        if (c == 0) {
                            abort;
                        }
                    }
                    error err => {
                        // The transaction can be force retried using `retry` keyword at any time.
                        io:println(err);
                        retry;
                    }
                }

                //Inserting to OpportunityProducts table
                foreach lineItem in opportunity["OpportunityLineItems"]{
                    var lineItemsResult = mysqlEP->update(QUERY_TO_INSERT_VALUES_TO_OPPORTUNITY_PRODUCTS,
                    lineItem["Id"].toString(), opportunity["Id"].toString(),
                    lineItem["Product"].toString(),
                    lineItem["Product"].toString(),
                    lineItem["Quantity"].toString(),
                    lineItem["Environment"].toString());
                    match lineItemsResult {
                        int c => {
                            io:println("Inserted count: " + c);
                            // The transaction can be force aborted using the `abort` keyword at any time.
                            if (c ==0) {
                                abort;
                            }
                        }
                        error err => {
                            // The transaction can be force retried using `retry` keyword at any time.
                            io:println(err);
                            retry;
                        }
                    }
                }

                //Inserting to SupportAccount table
                    var supportAccResult = mysqlEP -> update(QUERY_TO_INSERT_VALUES_TO_SUPPORT_ACCOUNT,
                    opportunity["SupportAccount"]["Id"].toString(),
                    opportunity["Id"].toString(),
                    opportunity["SupportAccount"]["JiraKey"].toString(),
                    opportunity["SupportAccount"]["StartDate"].toString(),
                    opportunity["SupportAccount"]["EndDate"].toString());
                    match supportAccResult {
                        int c => {
                                    io:println("Inserted count: " + c);
                                    // The transaction can be force aborted using the `abort` keyword at any time.
                                if (c == 0) {
                                    abort;
                                }
                        }
                        error err => {
                            // The transaction can be force retried using `retry` keyword at any time.
                            io:println(err);
                            retry;
                        }
                    }
                }
            }
        }
        onretry {
            log:printInfo("Retrying transaction...");
        }
    }
}


function onCommitFunction(string transactionId) {
    log:printDebug("Successful! Upsertion transaction comitted with transaction ID: " + transactionId);
}

function onAbortFunction(string transactionId) {
    log:printDebug("Failed! Upsertion transaction aborted with transaction ID: " + transactionId);
}

function handleError(string message, error e, mysql:Client testDB) {
    io:println(message + e.message);
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
    io:println(resultQuery);
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
