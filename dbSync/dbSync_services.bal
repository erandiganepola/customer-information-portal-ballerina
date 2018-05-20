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
import ballerina/system;
import sfdc37;
import dataCollector as dc;

endpoint mysql:Client mysqlEP {
    host: config:getAsString("SFDB_HOST"),
    port: config:getAsInt("SFDB_PORT"),
    name: config:getAsString("SFDB_NAME"),
    username: config:getAsString("SFDB_USERNAME"),
    password: config:getAsString("SFDB_PASSWORD"),
    dbOptions: { "useSSL": false },
    poolOptions: { maximumPoolSize: config:getAsInt("SFDB_POOL_SIZE") }
};

endpoint http:Client httpClientEP {
    url: config:getAsString("DATA_COLLECTOR_URI"),
    timeoutMillis: 300000
};


endpoint http:Listener listener {
    port: config:getAsInt("DB_SYNC_SERVICE_HTTP_PORT")
};

@http:ServiceConfig {
    endpoints: [listener],
    basePath: "/sync"
}
service<http:Service> dataSyncService bind listener {

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/salesforce/start"
    }
    startSalesforceService(endpoint caller, http:Request request) {
        log:printInfo("Requesting full sync for Salesforce data!");
        http:Response response = new;
        string batchId = system:uuid();
        if (updateSyncRequestedStatus(batchId)) {
            response.setJsonPayload({ "sucess": true, error: null });
        } else {
            response.setJsonPayload({ "sucess": false, error: "Unable to update batch status" });
        }
        _ = caller->respond(response);
    }

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/salesforce"
    }
    syncSalesforceData(endpoint caller, http:Request request) {
        log:printInfo("Sync service triggered!");
        http:Response response = new;
        _ = caller->respond(response);

        string batchId = system:uuid();
        // update batch ID and check batch status
        match updateUuidAndGetBatchStatus(batchId) {
            BatchStatus bs => {
                if (bs.state == BATCH_STATUS_COMPLETED){
                    // Nothing to do
                    log:printInfo("Last batch has been completed successfully. Nothing to do. Aborting");
                } else if (bs.state == BATCH_STATUS_SYNC_REQUESTED){
                    // Do a full sync
                    log:printInfo("Starting a full sync");
                    if (clearRecordStatusTable() && checkAndSetInProgressState(batchId)){
                        log:printDebug("Getting active JIRA keys from JIRA");
                        match getJiraKeysFromJira() {
                            string[] jiraKeys => {
                                syncSfDataForJiraKeys(batchId, jiraKeys);
                                //syncSfDataForJiraKeys(batchId, jiraKeysToBeUpserted);
                            }
                            error e => log:printError("Error occurred while getting JIRA keys.", err = e);
                        }
                    } else {
                        log:printWarn("Couldn't clear record status table or update IN_PROGRESS state. Aborting");
                    }
                } else if (bs.state == BATCH_STATUS_IN_PROGRESS){
                    // Complete records which haven't been completed
                    log:printInfo("Starting completing incompleted records");
                    string[] jiraKeys = getIncompletedRecordJiraKeys();
                    syncSfDataForJiraKeys(batchId, jiraKeys);
                    //syncSfDataForJiraKeys(batchId, jiraKeysToBeUpserted);
                } else {
                    log:printWarn("Unknown batch state: " + bs.state);
                }
            }
            () => {
                // No sync request or anything. Ignore
                log:printInfo("No state found in BatchStatus table. Aborting");
            }
        }
    }

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/jira/start"
    }
    startJiraService(endpoint caller, http:Request request) {
        log:printInfo("Requesting full sync for Jira Projects data!");
        http:Response response = new;

        match getJiraProjectDetailsFromJira() {
            json[] jsonProjects => {
                if (upsertToJiraProject(jsonProjects)){
                    response.setJsonPayload({ "sucess": true, error: null });
                } else {
                    response.setJsonPayload({ "sucess": false, error: "Unable to upsert records!" });
                }
            }
            error e => {
                response.setJsonPayload({ "sucess": false,
                        error: "Unable to get JiraProject details!" + e.message });
            }
        }
        _ = caller->respond(response);
    }
}