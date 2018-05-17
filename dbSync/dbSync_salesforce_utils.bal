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
    log:printDebug("Updating BtachStatus state in to: " + BATCH_STATUS_SYNC_REQUESTED);
    transaction with retries = 3, oncommit = onCommit, onabort = onAbort {
        match getBatchStatusWithLock() {
            BatchStatus bs => {
                boolean result = setBatchStatus(uuid, BATCH_STATUS_SYNC_REQUESTED);
            }
            () => {
                boolean result = addBatchStatus(uuid, BATCH_STATUS_SYNC_REQUESTED);
            }
            error => {
                retry;
            }
        }
    } onretry {
        log:printWarn("Retrying transaction to update batch status to: " + BATCH_STATUS_SYNC_REQUESTED);
    }

    match getBatchStatus() {
        BatchStatus bs => return bs.uuid == uuid && bs.state == BATCH_STATUS_SYNC_REQUESTED;
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

function syncSfDataForJiraKeys(string uuid, string[] jiraKeys) {
    log:printInfo("Syncing " + (lengthof jiraKeys) + " JIRA keys");

    string[] paginatedKeys = [];
    json[] paginatedRecords;
    int lengthOfJiraKeys = lengthof jiraKeys;
    int paginateLimit = PAGINATE_LIMIT;
    int i = 0;
    int j = 0;
    int k = 0;

    // TODO simplify the logic
    while (lengthOfJiraKeys > 0){
        paginatedKeys[i] = jiraKeys[j];
        i++;
        j++;
        io:println(j);
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
                                        log:printInfo((lengthof records) + " salesforce records fetched");

                                        if (lengthof records == 0) {
                                            log:printWarn("No Salesforce record found. Aborting");
                                        } else {
                                            //when appending records for the first time
                                            if (lengthof paginatedRecords == 0) {
                                                paginatedRecords = <json[]>records;
                                            } else {
                                                //if the salesforce response is paginated
                                                k = lengthof paginatedRecords;
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
        string jiraKey = record[SUPPORT_ACCOUNTS__R][RECORDS][JIRA_KEY_INDEX]
        [JIRA_KEY__C].toString();
        io:println(jiraKey);

        json opportunity = {
            "Id": record[ID],
            "Account": {
                "Id": record[ACCOUNT][ID],
                "Name": record[ACCOUNT][NAME],
                "Classification": record[ACCOUNT][ACCOUNT_CLASSIFICATION__C],
                "Owner": record[ACCOUNT][OWNER][NAME],
                "Rating": record[ACCOUNT][RATING],
                "TechnicalOwner": record[ACCOUNT][TECHNICAL_OWNER__C],
                "Industry": record[ACCOUNT][INDUSTRY],
                "Phone": record[ACCOUNT][PHONE],
                "BillingAddress": record[ACCOUNT][BILLING_ADDRESS]
            },
            "SupportAccounts": [],
            "OpportunityLineItems": []
        };

        foreach supportAccount in record[SUPPORT_ACCOUNTS__R][RECORDS] {
            json account = {
                "Id": supportAccount[ID],
                "JiraKey": supportAccount[JIRA_KEY__C],
                "StartDate": supportAccount[START_DATE__C],
                "EndDate": supportAccount[END_DATE__C]
            };

            opportunity[SUPPORT_ACCOUNTS][lengthof opportunity[SUPPORT_ACCOUNTS]] = account;
        }

        if (record[OPPORTUNITY_LINE_ITEMS][RECORDS] != ()){
            foreach item in record[OPPORTUNITY_LINE_ITEMS][RECORDS] {
                json lineItem = {
                    "Id": item[ID],
                    "Quantity": item[QUANTITY],
                    "Environment": item[ENVIRONMENT__C],
                    "Product": item[PRICEBOOK_ENTRY][NAME]
                };

                opportunity[OPPORTUNITY_LINE_ITEMS][lengthof opportunity[OPPORTUNITY_LINE_ITEMS]] = lineItem;
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
                return <string[]>jsonResponse[DATA_COLLECTOR_RESPONSE];
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

    values = values.replaceFirst(COMMA, EMPTY_STRING);

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

    // TODO check whether all those keys were inserted with NULL completed_time (check successfull?)
}

function buildQueryFromTemplate(string template, string replace, string[] entries) returns string {
    string values = EMPTY_STRING;
    foreach entry in entries {
        values += COMMA + SINGLE_QUOTATION + entry + SINGLE_QUOTATION;
    }
    values = values.replaceFirst(COMMA, EMPTY_STRING);

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
                    opportunity[ACCOUNT][ID].toString(),
                    opportunity[ACCOUNT][NAME].toString(),
                    opportunity[ACCOUNT][CLASSIFICATION].toString(),
                    opportunity[ACCOUNT][RATING].toString(),
                    opportunity[ACCOUNT][OWNER].toString(),
                    opportunity[ACCOUNT][TECHNICAL_OWNER].toString(),
                    opportunity[ACCOUNT][INDUSTRY].toString(),
                    opportunity[ACCOUNT][PHONE].toString(),
                    opportunity[ACCOUNT][BILLING_ADDRESS][CITY].toString(),
                    opportunity[ACCOUNT][BILLING_ADDRESS][COUNTRY].toString(),
                    opportunity[ACCOUNT][BILLING_ADDRESS][GEOCODEACCURACY].toString(),
                    opportunity[ACCOUNT][BILLING_ADDRESS][LATITUDE].toString(),
                    opportunity[ACCOUNT][BILLING_ADDRESS][LONGITUDE].toString(),
                    opportunity[ACCOUNT][BILLING_ADDRESS][POSTAL_CODE].toString(),
                    opportunity[ACCOUNT][BILLING_ADDRESS][STATE].toString(),
                    opportunity[ACCOUNT][BILLING_ADDRESS][STREET].toString());

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
                    opportunity[ID].toString(),
                    opportunity[ACCOUNT][ID].toString());
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
                log:printDebug(string `Inserting {{lengthof opportunity[OPPORTUNITY_LINE_ITEMS]}} OpportunityProducts`);
                foreach lineItem in opportunity[OPPORTUNITY_LINE_ITEMS] {
                    var lineItemsResult = mysqlEP->update(QUERY_TO_INSERT_VALUES_TO_OPPORTUNITY_PRODUCTS,
                        lineItem[ID].toString(), opportunity[ID].toString(), lineItem[PRODUCT].toString(),
                        lineItem[PRODUCT].toString(), lineItem[QUANTITY].toString(),
                        lineItem[ENVIRONMENT].toString());

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

                foreach supportAccount in opportunity[SUPPORT_ACCOUNTS] {
                    //Inserting to SupportAccount table
                    sql:Parameter startDate = {
                        sqlType: sql:TYPE_DATE,
                        value: null
                    };

                    sql:Parameter endDate = {
                        sqlType: sql:TYPE_DATE,
                        value: null
                    };

                    if (supportAccount[START_DATE] != ()){
                        startDate = {
                            sqlType: sql:TYPE_DATE,
                            value: supportAccount[START_DATE].toString()
                        };
                    }

                    if (supportAccount[END_DATE] != ()){
                        endDate = {
                            sqlType: sql:TYPE_DATE,
                            value: supportAccount[END_DATE].toString()
                        };
                    }
                    var supportAccResult = mysqlEP->update(QUERY_TO_INSERT_VALUES_TO_SUPPORT_ACCOUNT,
                        supportAccount[ID].toString(), opportunity[ID].toString(),
                        supportAccount[JIRA_KEY].toString(), startDate, endDate);
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

            //Update record completed time
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

function onCommit(string transactionId) {
    log:printDebug("Transaction comitted with transaction ID: " + transactionId);
}

function onAbort(string transactionId) {
    log:printDebug("Failed - aborted transaction with transaction ID: " + transactionId);
}
