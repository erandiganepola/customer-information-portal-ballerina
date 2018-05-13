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
    host: config:getAsString("HOST"),
    port: config:getAsInt("PORT"),
    name: config:getAsString("NAME"),
    username: config:getAsString("USERNAME"),
    password: config:getAsString("PASSWORD"),
    dbOptions: { "useSSL": false },
    poolOptions: { maximumPoolSize: config:getAsInt("POOL_SIZE") }
};

endpoint http:Client httpClientEP {
    url: config:getAsString("HTTP_ENDPOINT_URL"),
    timeoutMillis: 300000
};


endpoint http:Listener listener {
    port: config:getAsInt("DATA_SYNC_SERVICE_HTTP_PORT")
};

@http:ServiceConfig {
    endpoints: [listener],
    basePath: "/sync/salesforce"
}
service<http:Service> dataSyncService bind listener {

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/start"
    }
    startSyncData(endpoint caller, http:Request request) {
        log:printInfo("Sync service triggered!");
        http:Response response = new;
        _ = caller->respond(response);

        // TODO generate UUID and update batch_id with that
        // TODO check batch status

        log:printInfo("Getting active JIRA keys...");
        string[] keysFromJira;
        match getJiraKeysFromJira() {
            string[] keys => keysFromJira = keys;
            error e => log:printError("Error occurred while getting JIRA keys. Error: " + e.message);
        }
        //string[] keysFromSfDb;
        //match getJiraKeysFromDB() {
        //    string[] keys => keysFromSfDb = keys;
        //    error e => log:printError("Error occurred while getting JIRA keys. Error: " + e.message);
        //}
        //
        ////Get JIRA keys toBeDeleted and toBeUpserted
        //log:printDebug("Categorizing keys to be deleted and upserted!");
        //map categorizedJiraKeys = categorizeJiraKeys(keysFromJira, keysFromSfDb);
        //
        //string[] jiraKeysToBeDeleted;
        //match <string[]>categorizedJiraKeys.toBeDeleted {
        //    string[] keys => jiraKeysToBeDeleted = keys;
        //    error e => log:printError("Error occurred while casting <string[]>jiraKeysToBeDeleted.
        //    Error: " + e.message);
        //}
        //json[] jiraKeysToBeUpserted;
        //match <json[]>categorizedJiraKeys.toBeUpserted {
        //    json[] keys => jiraKeysToBeUpserted = keys;
        //    error e => log:printError("Error occurred while casting <string[]>jiraKeysToBeUpserted.
        //    Error: " + e.message);
        //}
        //
        //log:printInfo("Starting sync with Salesforce DB...");
        //
        //log:printInfo("Deleting records from Salesforce DB...");
        //deleteJiraKeys(jiraKeysToBeDeleted);

        log:printInfo("Fetching data from Salesforce API ...");
        http:Request httpRequest = new;
        httpRequest.setJsonPayload(jiraKeysToBeUpserted);
        var sfResponse = httpClientEP->post("/collector/salesforce/", request = httpRequest);
        // Fetched salesforce data for given jira keys
        match sfResponse {
            http:Response resp => {
                match resp.getJsonPayload() {
                    json jsonPayload => {

                        log:printDebug("Received payload from salesforce: " + jsonPayload.toString());

                        // Got json payload. Now check whether request was successful
                        if (jsonPayload == ()){
                            log:printError("No data returned from salesforce API");
                        } else {
                            json sfData = jsonPayload["response"];
                            log:printDebug("Salesforce data fetched");

                            if (sfData == ()){
                                log:printError("Couldn't fecth salesforce data");
                            } else {
                                map organizedSfDataMap = organizeSfData(sfData);

                                log:printInfo("Updating record statuses");
                                if (upsertRecordStatus(organizedSfDataMap.keys())){
                                    log:printInfo("Upserting records into Salesforce DB ...");
                                    upsertDataIntoSfDb(organizedSfDataMap);

                                    // TODO if all jira keys' status are ok, update batch status
                                } else {
                                    log:printError("Unable to insert record status properly. Aborting");
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