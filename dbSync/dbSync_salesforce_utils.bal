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


function syncSfDataForJiraKeys(string uuid, string[] jiraKeys) {
    log:printInfo("Syncing " + (lengthof jiraKeys) + " JIRA keys");

    json[] records = [];
    int i = 0;
    string[] keys = [];
    while (i < lengthof jiraKeys) {
        keys[i % BATCH_SIZE] = jiraKeys[i];

        if (i > 0 && (i % BATCH_SIZE == 0 || i == lengthof jiraKeys - 1)) {
            json[] newRecords = collectSFData(keys);
            int k = lengthof records;
            foreach rec in newRecords {
                records[k] = rec;
                k++;
            }

            keys = [];
        }
        i++;
    }

    if (lengthof records == 0) {
        if (lengthof jiraKeys > 0) {
            log:printWarn("No SF record found even though there are " + (lengthof jiraKeys) + " jira keys. Aborting");
        } else {
            log:printWarn("No record found to be synced. Aborting");
        }
        return;
    }

    // Sending full Salesforce data set to be organized
    log:printDebug("Salesforce records count : " + (lengthof records));
    map organizedSfDataMap = organizeSfData(jiraKeys, records);

    if (upsertRecordStatus(organizedSfDataMap.keys())){
        log:printInfo(string `Upserting {{lengthof organizedSfDataMap.keys()}} records into Salesforce DB ...`);
        upsertDataIntoSfDb(organizedSfDataMap, uuid);
        checkAndSetBatchCompleted(jiraKeys, uuid);
    } else {
        log:printError("Unable to insert record status properly. Aborting");
    }
}


function collectSFData(string[] jiraKeys) returns json[] {
    json[] results = [];
    http:Request httpRequest = new;
    match <json>jiraKeys {
        json keys => httpRequest.setJsonPayload(keys);
        error e => {
            log:printError("Unable to cast jira key array to json[]", err = e);
            return results;
        }
    }

    log:printDebug(string `Fetching data from Salesforce API for {{lengthof jiraKeys}} keys`);
    var sfResponse = httpClientEP->post("/collector/salesforce/", request = httpRequest);
    match sfResponse {
        http:Response resp => {
            match resp.getJsonPayload() {
                json jsonPayload => {
                    log:printDebug("Received Json payload from salesforce");
                    // Got json payload. Now check whether request was successful
                    if (jsonPayload == () || jsonPayload["success"].toString() == "false") {
                        error? e = <error>jsonPayload["error"];
                        log:printError("No data returned from salesforce API", err = e);
                    } else {
                        match <json[]>jsonPayload["response"]{
                            json[] records => {
                                log:printDebug((lengthof records) + " salesforce records fetched");
                                results = records;
                            }
                            error e => log:printError("Unable to cast Salesforce records", err = e);
                        }
                    }
                }
                error e => log:printError("Error occurred while extracting Json payload", err = e);
            }
        }
        error e => log:printError("Error occured when fetching data from Salesforce.", err = e);
    }

    return results;
}

function organizeSfData(string[] jiraKeys, json[] records) returns map {
    map<json[]> sfDataMap;

    foreach jiraKey in jiraKeys {
        sfDataMap[jiraKey] = [];
    }

    foreach record in records {
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

        string[] keys = [];

        // Skipping null jira keys
        if (record[SUPPORT_ACCOUNTS__R] != ()) {
            match <json[]>record[SUPPORT_ACCOUNTS__R][RECORDS] {
                json[] supportAccounts => {
                    foreach supportAccount in supportAccounts {
                        if (supportAccount[JIRA_KEY__C] != ()){
                            keys[lengthof keys] = supportAccount[JIRA_KEY__C].toString();
                        } else {
                            log:printWarn("Found 'null' JIRA key for support account: " + supportAccount.toString());
                        }
                    }
                }
                error e => {
                    log:printError("Unable to get support accounts for opportunity: " + record[ID].toString(), err = e);
                }
            }

            foreach supportAccount in record[SUPPORT_ACCOUNTS__R][RECORDS] {
                json account = {
                    "Id": supportAccount[ID],
                    "JiraKey": supportAccount[JIRA_KEY__C],
                    "StartDate": supportAccount[START_DATE__C],
                    "EndDate": supportAccount[END_DATE__C]
                };

                opportunity[SUPPORT_ACCOUNTS][lengthof opportunity[SUPPORT_ACCOUNTS]] = account;
            }
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

        foreach jiraKey in keys {
            if (!sfDataMap.hasKey(jiraKey)) {
                log:printDebug("Adding new Jira key: " + jiraKey);
                sfDataMap[jiraKey] = [opportunity];
            } else {
                //log:printDebug("Adding data for existing Jira key: " + jiraKey);
                int index = (lengthof sfDataMap[jiraKey]);
                sfDataMap[jiraKey][index] = opportunity;
            }
        }
    }
    return sfDataMap;
}

// Upsert data into Salesforce database tables
function upsertDataIntoSfDb(map organizedDataMap, string uuid) {
    foreach key, value in organizedDataMap{
        log:printDebug("\n");
        log:printInfo("Upserting transaction starting for jira key : " + key);
        // Start transaction
        transaction with retries = 3, oncommit = onUpsertCommitFunction, onabort = onUpsertAbortFunction {
            match getRecordStatusWithLock(key) {
                // TODO should we take RecordStatus lock first and check BatchStatus, or other way round?
                RecordStatus => {
                    log:printDebug(string `RecorsStatus table row locked for key: {{key}}`);
                    // Batch status table is not locked at the moment. Should it be locked as well?
                    match getBatchStatus() {
                        BatchStatus bs => {
                            if (bs.uuid != uuid) {
                                log:printWarn(string `UUID has changed from {{uuid}} to {{bs.uuid}}
                                    . Another process has taken over`);
                                abort;
                            }
                        }
                        () => {
                            log:printWarn("No batch status found. Aborting");
                            abort;
                        }
                        error e => {
                            //log:printError("Unable to get batch status. Aborting", err = e);
                            retry;
                        }
                    }
                }
                () => {
                    //log:printDebug(string `Unable to lock RecorsStatus table row for key: {{key}}`);
                    retry;
                }
                error e => {
                    //log:printError("Error occured when getting the row lock for key: " + key, err = e);
                    retry;
                }
            }

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
                    error e => retry;

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
                    error e => retry;
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
                        error e => retry;
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
                error e => retry;
            }
        }
        onretry {
            log:printWarn("Retrying transaction to insert records...");
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
