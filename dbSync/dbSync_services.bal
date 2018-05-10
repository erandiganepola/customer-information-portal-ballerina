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

function onCommitFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " committed");
}

function onAbortFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " aborted");
}

function handleError(string message, error e, mysql:Client testDB) {
    io:println(message + e.message);
}