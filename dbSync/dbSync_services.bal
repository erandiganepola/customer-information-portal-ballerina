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

import ballerina/mysql;
import ballerina/io;
import ballerina/http;
import ballerina/config;
import ballerina/log;
import sfdc37;
import dataCollector as dc;

endpoint mysql:Client mysqlEP {
    host:config:getAsString("HOST"),
    port:config:getAsInt("PORT"),
    name:config:getAsString("NAME"),
    username:config:getAsString("USERNAME"),
    password:config:getAsString("PASSWORD"),
    dbOptions:{"useSSL":false},
    poolOptions:{maximumPoolSize:config:getAsInt("POOL_SIZE")}
};

endpoint http:Client httpClientEP{
    url:config:getAsString("HTTP_ENDPOINT_URL")
};


endpoint http:Listener listener {
    port:config:getAsInt("DATA_SYNC_SERVICE_HTTP_PORT")
};

@http:ServiceConfig {
    endpoints:[listener],
    basePath:"/sync/salesforce"
}
service<http:Service> dataSyncService bind listener {

    @http:ResourceConfig {
        methods:["POST"],
        path:"/start"
    }
    startSyncData(endpoint caller, http:Request request) {
        log:printInfo("Sync service triggered!");
        http:Response response = new;
        _ = caller -> respond(response);

        log:printDebug("Getting active JIRA keys...");
        string[] keysFromJira = check getJiraKeysFromJira();
        string[] keysFromSfDb = check getJiraKeysFromDB();

        //Get JIRA keys toBeDeleted and toBeUpserted
        log:printDebug("Categorizing keys to be deleted and upserted!");
        map categorizedJiraKeys = dc:categorizeJiraKeys(keysFromJira, keysFromSfDb);

        string[] jiraKeysToBeDeleted = check <string[]>categorizedJiraKeys.toBeDeleted;
        json[] jiraKeysToBeUpserted = check <json[]>categorizedJiraKeys.toBeUpserted;

        log:printInfo("Starting sync with Salesforce DB...");

        log:printInfo("Deleting records from Salesforce DB...");
        deleteJiraKeys(jiraKeysToBeDeleted);

        log:printDebug("Getting data from Salesforce API...");

        http:Request httpRequest = new;
        map organizedSfDataMap;
        httpRequest.setJsonPayload(jiraKeysToBeUpserted);
        var out = httpClientEP->post("/collector/salesforce/", request = httpRequest);
        match out {
            http:Response resp => {
                log:printDebug("Successfully fetched data from Salesforce API");
                organizedSfDataMap = organizeSfData(check resp.getJsonPayload());
                io:println(organizedSfDataMap);

                log:printInfo("Upserting records into Salesforce DB...");
                upsertDataIntoSfDb(organizedSfDataMap);
            }
            error err => {
                log:printError("Error occured when fetching data from Salesforce. Error: " + err.message);
            }
        }
    }
}

//======================================================================================================//
//Transaction util functions





//function deleteJiraKeys(string[] jiraKeysToBeDeleted) {
//    string[] oppIds;
//    string[] oppIdsToBeDeleted;
//    string[] accountIds;
//    string[] accountIdsToBeDeleted;
//
//    log:printDebug("Starting transaction: deleting records from Salesforce DB...");
//    transaction with retries = 4, oncommit = onCommitFunction, onabort = onAbortFunction {
//
//    // Get JIRA keys from SF DB, RecordStatus table
//    var selectResultsJiraKeys = mysqlEP -> select(QUERY_TO_GET_JIRA_KEYS_FROM_RECORD_STATUS_TABLE, ());
//    match selectResultsJiraKeys {
//        table tableReturned => {
//            io:println(tableReturned);
//        }
//        error err => {
//            log:printError("SELECT query failed! Error: " + err.message);
//        }
//    }
//
//    // Get Opportunity Ids by jira keys
//    var selectResultsOppIds = mysqlEP -> select(dc:buildQueryFromTemplate(
//        QUERY_TEMPLATE_GET_OPPORTUNITY_IDS_BY_JIRA_KEYS, jiraKeysToBeDeleted), ());
//    match selectResultsOppIds {
//        table tableReturned => {
//            io:println(tableReturned);
//            string[] oppIds;
//        }
//        error err => {
//            log:printError("SELECT query failed! Error: " + err.message);
//        }
//    }
//
//    // Out of those Opportunity Ids, find which are not used in other Support Accounts to be deleted
//    var selectResultsOppIdsToDelete = mysqlEP -> select(dc:buildQueryFromTemplate(
//        QUERY_TEMPLATE_GET_OPPORTUNITY_IDS_TO_BE_DELETED, oppIds), ());
//    match selectResultsOppIdsToDelete {
//        table tableReturned => {
//            io:println(tableReturned);
//            string[] oppIdsToBeDeleted;
//        }
//        error err => {
//            log:printError("SELECT query failed! Error: " + err.message);
//        }
//    }
//
//    // Get Account Ids by Opportunity Ids
//    var selectResultsAccIds = mysqlEP -> select(dc:buildQueryFromTemplate(
//        QUERY_TEMPLATE_GET_ACCOUNT_IDS_BY_OPPORTUNITY_IDS, oppIdsToBeDeleted), ());
//    match selectResultsAccIds {
//        table tableReturned => {
//            io:println(tableReturned);
//            string[] accountIds;
//        }
//        error err => {
//            log:printError("SELECT query failed! Error: " + err.message);
//        }
//    }
//
//    // Get Account Ids to be deleted
//    var selectResultsAccIdsToDelete = mysqlEP -> select(dc:buildQueryFromTemplate(
//        QUERY_TEMPLATE_GET_ACCOUNT_IDS_TO_BE_DELETED, accountIds), ());
//    match selectResultsAccIdsToDelete {
//        table tableReturned => {
//            io:println(tableReturned);
//            string[] accountIdsToBeDeleted;
//        }
//        error err => {
//            log:printError("SELECT query failed! Error: " + err.message);
//        }
//    }
//
//    var result = mysqlEP -> update(dc:buildQueryFromTemplate
//        (QUERY_TEMPLATE_DELETE_FROM_SUPPORT_ACCOUNT_BY_JIRA_KEYS, jiraKeysToBeDeleted));
//
//    result = mysqlEP -> update(dc:buildQueryFromTemplate
//        (QUERY_TEMPLATE_DELETE_FROM_ACCOUNT_BY_ACCOUNT_IDS, accountIdsToBeDeleted));
//
//    result = mysqlEP -> update(dc:buildQueryFromTemplate
//        (QUERY_TEMPLATE_DELETE_FROM_OPPORTUNITY_BY_OPPORTUNITY_IDS, oppIdsToBeDeleted));
//
//    // Can do this with "ON DELETE CASCADE"
//    result = mysqlEP -> update(dc:buildQueryFromTemplate
//        (QUERY_TEMPLATE_DELETE_FROM_OPPORTUNITY_PRODUCT_BY_IDS, oppIdsToBeDeleted));
//
//    //TODO: Update BatchStatus table deletion_completed_time
//
//    match result {
//        int c => {
//            log:printDebug("Deletion transaction completed successfully!!");
//
//        // The transaction can be force aborted using the `abort` keyword at any time.
//            if (c == 0) {
//                abort;
//                }
//            }
//        error err => {
//        // The transaction can be force retried using `retry` keyword at any time.
//            io:println(err);
//            retry;
//            }
//        }
//    } onretry {
//        io:println("Retrying transaction");
//    }
//}
//
//function upsertDataIntoSfDb(map organizedDataMap){
//log:printDebug("Upsertion transaction starting...");
//
//    foreach upsertKey in organizedDataMap {
//        transaction with retries =3, oncommit = onCommitFunction, onabort = onAbortFunction {
//            foreach key, value in organizedDataMap{
//                //Start transaction
//                foreach opportunity in check <json[]>value{
//
//                    //Inserting to Account table
//                    var accountResult = mysqlEP -> update(QUERY_TO_INSERT_VALUES_TO_ACCOUNT,
//                    opportunity["Account"]["Id"].toString(), opportunity["Account"]["Name"].toString(),
//                    opportunity["Account"]["Classification"].toString(), opportunity["Account"]["Rating"].toString(),
//                    opportunity["Account"]["Owner"].toString(), opportunity["Account"]["TechnicalOwner"].toString(),
//                    opportunity["Account"]["Industry"].toString(), opportunity["Account"]["Phone"].toString(),
//                    opportunity["Account"]["BillingAddress"]["city"].toString());
//                    // todo Make billling address flat -> add more columns to table (city, street, etc.)
//                    match accountResult {
//                        int c => {
//                            io:println("Inserted count: " + c);
//                            // The transaction can be force aborted using the `abort` keyword at any time.
//                            if (c == 0) {
//                                abort;
//                            }
//                        }
//                        error err => {
//                            // The transaction can be force retried using `retry` keyword at any time.
//                            io:println(err);
//                            retry;
//                        }
//                    }
//
//                    //Inserting to Opportunity table
//                    var oppResult = mysqlEP -> update(QUERY_TO_INSERT_VALUES_TO_OPPORTUNITY,
//                    opportunity["SuppportAccount"]["Id"].toString(), opportunity["Id"].toString(),
//                    opportunity["SuppportAccount"]["JiraKey"].toString(),
//                    opportunity["SuppportAccount"]["StartDate"].toString(),
//                    opportunity["SuppportAccount"]["EndDate"].toString());
//                    match oppResult {
//                        int c => {
//                            io:println("Inserted count: " + c);
//                            // The transaction can be force aborted using the `abort` keyword at any time.
//                            if (c == 0) {
//                                abort;
//                            }
//                        }
//                        error err => {
//                            // The transaction can be force retried using `retry` keyword at any time.
//                            io:println(err);
//                            retry;
//                        }
//                    }
//
//                    //Inserting to OpportunityProducts table
//                    foreach lineItem in opportunity["OpportunityLineItems"]{
//                        var lineItemsResult = mysqlEP->update(QUERY_TO_INSERT_VALUES_TO_OPPORTUNITY_PRODUCTS,
//                                                    lineItem["Id"].toString(), opportunity["Id"].toString(),
//                                                    lineItem["Product"].toString(),
//                                                    lineItem["Product"].toString(),
//                                                    lineItem["Quantity"].toString(),
//                                                    lineItem["Environment"].toString());
//                        match lineItemsResult {
//                            int c => {
//                                io:println("Inserted count: " + c);
//                                // The transaction can be force aborted using the `abort` keyword at any time.
//                                if (c ==0) {
//                                    abort;
//                                }
//                            }
//                            error err => {
//                                // The transaction can be force retried using `retry` keyword at any time.
//                                io:println(err);
//                                retry;
//                            }
//                        }
//                    }
//
//                    //Inserting to SupportAccount table
//                    var supportAccResult = mysqlEP -> update(QUERY_TO_INSERT_VALUES_TO_SUPPORT_ACCOUNT,
//                    opportunity["SuppportAccount"]["Id"].toString(), opportunity["Id"].toString(),
//                    opportunity["SuppportAccount"]["JiraKey"].toString(),
//                    opportunity["SuppportAccount"]["StartDate"].toString(),
//                    opportunity["SuppportAccount"]["EndDate"].toString());
//                    match supportAccResult {
//                        int c => {
//                        io:println("Inserted count: " + c);
//                        // The transaction can be force aborted using the `abort` keyword at any time.
//                            if (c == 0) {
//                                abort;
//                            }
//                        }
//                        error err => {
//                            // The transaction can be force retried using `retry` keyword at any time.
//                            io:println(err);
//                            retry;
//                        }
//                    }
//
//                }
//            }
//        }
//        onretry {
//        io:println("Retrying transaction");
//        }
//    }
//}

function onCommitFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " committed");
}

function onAbortFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " aborted");
}

function handleError(string message, error e, mysql:Client testDB) {
    io:println(message + e.message);
}