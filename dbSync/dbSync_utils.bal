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

function updateSyncRequestedStatus(string uuid) returns boolean {
    log:printDebug("Updating BtachStatus state in to: " + BATCH_STATUS_SYNC);
    transaction with retries = 3, oncommit = onCommit, onabort = onAbort {
        match getBatchStatusWithLock() {
            BatchStatus bs => {
                boolean result = setBatchStatus(uuid, BATCH_STATUS_SYNC);
            }
            () => {
                boolean result = addBatchStatus(uuid, BATCH_STATUS_SYNC);
            }
            error => {
                retry;
            }
        }
    } onretry {
        log:printWarn("Retrying transaction to update batch status to: " + BATCH_STATUS_SYNC);
    }

    match getBatchStatus() {
        BatchStatus bs => return bs.uuid == uuid && bs.state == BATCH_STATUS_SYNC;
        ()|error => return false;
    }
}

function updateUuidAndGetBatchStatus(string uuid) returns BatchStatus|() {
    log:printInfo("Inserting UUID: " + uuid + " and getting batch status");
    transaction with retries = 3, oncommit = onCommit, onabort = onAbort {
        match getBatchStatusWithLock() {
            BatchStatus bs => {
                // Set batch uuid
                var updateResult = mysqlEP->update(QUERY_SET_BATCH_UUID, uuid);
                match updateResult {
                    int c => {
                        if (c < 0) {
                            log:printError("Unable to update UUID: " + uuid);
                            abort;
                        } else {
                            log:printInfo("Updated batch UUID: " + uuid);
                        }
                    }
                    error e => {
                        //log:printError("Unable to set UUID: " + uuid, err = e);
                        retry;
                    }
                }
            }
            () => {
                log:printWarn("No existing batch status found");
            }
            error e => {
                retry;
            }
        }
    } onretry {
        log:printWarn("Retrying transaction to update batch UUID: " + uuid);
    }

    match getBatchStatus() {
        BatchStatus bs => {
            return bs.uuid == uuid ? bs : ();
        }
        error|() => return ();
    }
}


function getBatchStatusWithLock() returns BatchStatus|()|error {
    BatchStatus|() batchStatus = ();
    var results = mysqlEP->select(QUERY_GET_BATCH_STATUS_WITH_LOCK, BatchStatus);
    // get batch status
    match results {
        table<BatchStatus> entries => {
            while (entries.hasNext()){
                match <BatchStatus>entries.getNext()  {
                    BatchStatus bs => batchStatus = bs;
                    error e => log:printError("Unable to get batch status", err = e);
                }
            }

            return batchStatus;
        }
        error e => {
            log:printError("Unable to get batch status", err = e);
            return e;
        }
    }
}

function getBatchStatus() returns BatchStatus|()|error {
    BatchStatus|() batchStatus = ();
    var results = mysqlEP->select(QUERY_GET_BATCH_STATUS, BatchStatus);
    // get batch status
    match results {
        table<BatchStatus> entries => {
            while (entries.hasNext()){
                match <BatchStatus>entries.getNext()  {
                    BatchStatus bs => batchStatus = bs;
                    error e => log:printError("Unable to get batch status", err = e);
                }
            }

            return batchStatus;
        }
        error e => {
            log:printError("Unable to get batch status", err = e);
            return e;
        }
    }
}

// Should be called within a transaction and having the row lock
function setBatchStatus(string uuid, string status) returns boolean {
    var updateResult = mysqlEP->update(QUERY_SET_BATCH_STATUS, uuid, status);
    match updateResult {
        int c => {
            if (c < 0) {
                log:printError("Unable to update BatctStatus in to: " + status);
                return false;
            } else {
                log:printInfo("Successful! Updated BatctStatus in to: " + status);
                return true;
            }
        }
        error e => {
            log:printError("Unable to update BatctStatus in to 'SYNC_REQUEST'");
            return false;
        }
    }
}

// Should be called within a transaction and having the row lock
function addBatchStatus(string uuid, string status) returns boolean {
    var result = mysqlEP->update(QUERY_INSERT_BATCH_STATUS, uuid, status);
    match result {
        int c => {
            if (c < 0) {
                log:printError("Unable to insert BatctStatus:" + status);
                return false;
            } else {
                log:printInfo("Successful! Inserted BatctStatus: " + status);
                return true;
            }
        }
        error e => {
            log:printError("Unable to insert BatctStatus: " + status);
            return false;
        }
    }
}

function checkAndSetInProgressState(string uuid) returns boolean {
    log:printInfo("Inserting UUID: " + uuid + " and setting batch status to `IN_PROGRESS`");
    BatchStatus|() batchStatus = ();
    transaction with retries = 3, oncommit = onCommit, onabort = onAbort {
        match getBatchStatusWithLock() {
            BatchStatus bs => {
                if (bs.uuid != uuid) {
                    log:printWarn(string `My UUID {{uuid}} is different from current batch UUID {{bs.uuid}}. Aborting`);
                    abort;
                }

                if (setBatchStatus(uuid, BATCH_STATUS_IN_PROGRESS)) {
                    log:printInfo("Updated batch status to " + BATCH_STATUS_IN_PROGRESS + " uuid: " + uuid);
                } else {
                    log:printError("Unable to update batch state to " + BATCH_STATUS_IN_PROGRESS + " uuid: " + uuid);
                }
            }
            () => {
                log:printWarn("No existing batch status found");
            }
            error e => {
                //log:printError("Unable to get batch status", err = e);
                retry;
            }
        }
    } onretry {
        log:printWarn("Retrying transaction to update IN_PROGRESS state for batch: " + uuid);
    }

    match getBatchStatus() {
        BatchStatus bs => return bs.uuid == uuid && bs.state == BATCH_STATUS_IN_PROGRESS;
        ()|error => return false;
    }
}


function checkAndSetBatchCompleted(string[] jiraKeys, string uuid) {
    log:printInfo("Checking for batch completion: " + uuid);
    transaction with retries = 3, oncommit = onCommit, onabort = onAbort {
        match getBatchStatusWithLock() {
            BatchStatus bs => {
                if (uuid != bs.uuid) {
                    log:printWarn(string `My UUID {{uuid}} is different from current batch {{bs.uuid}}. Aborting`);
                    return;
                }

                io:println(bs);

                if (lengthof jiraKeys == 0) {
                    log:printDebug("0 records left for completion. Marking as completed");
                    if (bs.state != BATCH_STATUS_COMPLETED && setBatchStatus(uuid, BATCH_STATUS_COMPLETED)) {
                        log:printInfo("Marked batch as : " + BATCH_STATUS_COMPLETED + " uuid: " + uuid);
                    }
                } else {
                    string q = buildQueryFromTemplate(QUERY_INCOMPLETE_RECORD_COUNT, "<JIRA_KEY_LIST>", jiraKeys);
                    var count = mysqlEP->select(q, RecordCount);
                    match count {
                        table tb => {
                            int count = 1;
                            //match <json>tb {
                            //    json j => io:println(j);
                            //    error e => io:println(e);
                            //}

                            while (tb.hasNext()) {
                                match <RecordCount>tb.getNext() {
                                    RecordCount rc => count = rc.c;
                                    error e => log:printError("Unable to read incomplete record count", err = e);
                                }
                            }

                            if (count == 0) {
                                log:printDebug("All records have been completed. Updating batch status");
                                if (setBatchStatus(uuid, BATCH_STATUS_COMPLETED)) {
                                    log:printInfo("Updated BatchStatus to " + BATCH_STATUS_COMPLETED);
                                } else {
                                    log:printError("Unable to update batch state to : " + BATCH_STATUS_COMPLETED);
                                }
                            } else {
                                log:printWarn(count +
                                        " records hasn't been completed. Not marking batch as completed");
                            }
                        }
                        error e => log:printError("Unable to get incompleted records", err = e);
                    }
                }
            }
            () => {
                log:printWarn("No batch status found");
            }
            error e => {
                retry;
            }
        }
    } onretry {
        log:printWarn("Retrying transaction to check batch completion: Batch - " + uuid);
    }
}

function getIncompletedRecordJiraKeys() returns string[] {
    string[] jiraKeys = [];

    var results = mysqlEP->select(QUERY_GET_INCOMPLETE_JIRA_KEYS, ());
    match results {
        table entries => {
            int i = 0;
            while (entries.hasNext()){
                string k = <string>entries.getNext();
                jiraKeys[i] = k;
                i++;
            }
        }
        error e => {
            log:printError("Unable to fetch incomplete records", err = e);
        }
    }

    return jiraKeys;
}

function syncSfForJiraKeys(string uuid, string[] jiraKeys) {
    log:printInfo("Syncing " + (lengthof jiraKeys) + " JIRA keys");

    string[] paginatedKeys = [];
    json[] paginatedRecords;
    int lengthOfJiraKeys = lengthof jiraKeys;
    int paginateLimit = PAGINATE_LIMIT;
    int i = 0;
    int j = 0;
    int k = 0;

    // TODO simplify
    while (lengthOfJiraKeys > 0){
        paginatedKeys[i] = jiraKeys[j];
        i++;
        j++;
        lengthOfJiraKeys--;

        if ((i == PAGINATE_LIMIT) || (lengthof jiraKeys < PAGINATE_LIMIT && i == lengthof jiraKeys - 1)){
            i = 0;
            http:Request httpRequest = new;
            match <json>paginatedKeys {
                json keys => {
                    httpRequest.setJsonPayload(keys);
                }
                error e => {
                    log:printError("Unable to cast jira key array to json[]", err = e);
                    return;
                }
            }

            log:printDebug("Fetching data from Salesforce API ...");
            var sfResponse = httpClientEP->post("/collector/salesforce/", request = httpRequest);
            match sfResponse {
                http:Response resp => {
                    match resp.getJsonPayload() {
                        json jsonPayload => {
                            log:printDebug("Received Json payload from salesforce");

                            // Got json payload. Now check whether request was successful
                            if (jsonPayload == () || jsonPayload["response"] == ()) {
                                log:printError("No data returned from salesforce API");
                            } else {
                                match <json[]>jsonPayload["response"]{
                                    json[] records => {
                                        log:printDebug((lengthof records) + " salesforce records fetched");

                                        if (lengthof records == 0) {
                                            log:printWarn("No Salesforce record found. Aborting");
                                        } else {
                                            //when appending records for the first time
                                            if (lengthof paginatedRecords == 0) {
                                                paginatedRecords = <json[]>records;
                                            } else {
                                                //if the salesforce response is paginated
                                                k = lengthof records;
                                                foreach record in records {
                                                    paginatedRecords[k] = record;
                                                    k++;
                                                }
                                            }
                                        }
                                    }
                                    error e => {
                                        log:printError("Unable to cast Salesforce records", err = e);
                                    }
                                }
                            }
                        }
                        error e => {
                            log:printError("Error occurred while receiving Json payload", err = e);
                        }
                    }
                }
                error e => {
                    log:printError("Error occured when fetching data from Salesforce. Error: " + e.message);
                }
            }
        }
    }

    // Sending full Salesforce data set to be organized
    log:printDebug("paginated records : " + (lengthof paginatedRecords));
    map organizedSfDataMap = organizeSfData(paginatedRecords);

    if (upsertRecordStatus(organizedSfDataMap.keys())){
        log:printInfo(string `Upserting {{lengthof organizedSfDataMap.keys()}} records into Salesforce DB ...`);
        upsertDataIntoSfDb(organizedSfDataMap);
        checkAndSetBatchCompleted(jiraKeys, uuid);
    } else {
        log:printError("Unable to insert record status properly. Aborting");
    }
}

function organizeSfData(json[] records) returns map {
    map<json[]> sfDataMap;
    foreach record in records {
        string jiraKey = record["Support_Accounts__r"]["records"][0]["JIRA_Key__c"].toString();

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
            "SupportAccounts": [],
            "OpportunityLineItems": []
        };

        foreach supportAccount in record["Support_Accounts__r"]["records"] {
            json account = {
                "Id": supportAccount["Id"],
                "JiraKey": supportAccount["JIRA_Key__c"],
                "StartDate": supportAccount["Start_Date__c"],
                "EndDate": supportAccount["End_Date__c"]
            };

            opportunity["SupportAccounts"][lengthof opportunity["SupportAccounts"]] = account;
        }

        if (record["OpportunityLineItems"]["records"] != ()){
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

function clearRecordStatusTable() returns boolean {
    var result = mysqlEP->update(QUERY_CLEAR_RECORD_STATUS_TABLE);
    match result {
        int c => {
            log:printDebug("Clear record status table");
            return c >= 0;
        }
        error e => {
            log:printError("Unable to clear RecordStatus table", err = e);
            return false;
        }
    }
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
            if (jsonResponse["success"].toString() == "true"){
                return <string[]>jsonResponse["response"];
            } else {
                string[] keys = [];
                return keys;
            }
        }
        error e => {
            log:printError("Failed to fetch JIRA keys from JIRA API. Error: " + e.message);
            return e;
        }
    }
}

function upsertRecordStatus(string[] jiraKeys) returns boolean {
    log:printDebug("Upserting " + lengthof jiraKeys + " record statuses");
    if (lengthof jiraKeys == 0) {
        log:printWarn("0 records to update status");
        return true;
    }

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

function buildQueryFromTemplate(string template, string replace, string[] entries) returns string {
    string values = "";
    foreach entry in entries {
        values += ",'" + entry + "'";
    }
    values = values.replaceFirst(",", "");

    return template.replace(replace, values);
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

                foreach supportAccount in opportunity["SupportAccounts"] {
                    //Inserting to SupportAccount table
                    sql:Parameter startDate = {
                        sqlType: sql:TYPE_DATE,
                        value: null
                    };

                    sql:Parameter endDate = {
                        sqlType: sql:TYPE_DATE,
                        value: null
                    };

                    if (supportAccount["StartDate"] != ()){
                        startDate = {
                            sqlType: sql:TYPE_DATE,
                            value: supportAccount["StartDate"].toString()
                        };
                    }

                    if (supportAccount["EndDate"] != ()){
                        endDate = {
                            sqlType: sql:TYPE_DATE,
                            value: supportAccount["EndDate"].toString()
                        };
                    }
                    var supportAccResult = mysqlEP->update(QUERY_TO_INSERT_VALUES_TO_SUPPORT_ACCOUNT,
                        supportAccount["Id"].toString(), opportunity["Id"].toString(),
                        supportAccount["JiraKey"].toString(), startDate, endDate);
                    match supportAccResult {
                        int c => {
                            if (c < 0) {
                                log:printError("Unable to insert support account: " + supportAccount.toString());
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

function hasJiraKey(string[] list, string key) returns boolean {
    foreach (item in list){
        if (item == key){
            return true;
        }
    }
    return false;
}

function onDeleteCommitFunction(string transactionId) {
    log:printDebug("Successful! Upsertion transaction comitted with transaction ID: " + transactionId);
}

function onDeleteAbortFunction(string transactionId) {
    log:printDebug("Failed! Upserting transaction aborted with transaction ID: " + transactionId);
}

function onCommit(string transactionId) {
    log:printDebug("Transaction comitted with transaction ID: " + transactionId);
}

function onAbort(string transactionId) {
    log:printDebug("Failed - aborted transaction with transaction ID: " + transactionId);
}

function handleDeletionError(string message, error e, mysql:Client testDB) {
    log:printError("Error occured during deletion. Error: " + e.message);
    io:println(message + e.message);
}
