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
    basePath: "/sync"
}
service<http:Service> dataSyncService bind listener {
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/salesforce/start"
    }
    startService(endpoint caller, http:Request request) {
        log:printInfo("Sync service triggered!");
        http:Response response = new;
        match updateSyncRequestedStatus() {
            () => { response.setJsonPayload({ "sucess": true, error: null });}
            error e => {
                response.setJsonPayload({ "sucess": false, error: e.message });
            }
        }
        _ = caller->respond(response);
    }

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/salesforce"
    }
    syncData(endpoint caller, http:Request request) {
        log:printInfo("Sync service triggered!");
        http:Response response = new;
        _ = caller->respond(response);

        string batchId = system:uuid().substring(0, 32);
        // update batch ID and check batch status
        match updateUuidAndGetBatchStatus(batchId) {
            BatchStatus bs => {
                if (bs.state == BATCH_STATUS_COMPLETED){
                    // Nothing to do
                    log:printInfo("Last batch has been completed successfully. Nothing to do. Aborting");
                } else if (bs.state == BATCH_STATUS_SYNC){
                    // Do a full sync
                    // TODO Set batch state to IN_PROGRESS
                    log:printInfo("Starting a full sync");
                    if (clearRecordStatusTable()){
                        log:printDebug("Getting active JIRA keys from JIRA");
                        match getJiraKeysFromJira() {
                            string[] jiraKeys => {
                                //syncSfForJiraKeys(batchId, jiraKeys);
                                syncSfForJiraKeys(batchId, jiraKeysToBeUpserted);
                            }
                            error e => log:printError("Error occurred while getting JIRA keys. Error: " + e.message);
                        }
                    } else {
                        log:printWarn("Couldn't clear record status table. Aborting");
                    }
                } else if (bs.state == BATCH_STATUS_IN_PROGRESS){
                    // Complete records which haven't been completed
                    log:printInfo("Starting completing incompleted records");
                    string[] jiraKeys = getIncompletedRecordJiraKeys();
                    syncSfForJiraKeys(batchId, jiraKeys);
                }
            }
            () => {
                // No sync request or anything. Ignore
                log:printInfo("No state found in BatchStatus table. Aborting");
            }
        }
    }
}