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
import ballerina/io;

function upsertToJiraProject(json[] projects) returns boolean {
    log:printDebug(string `Preparing Upsert query for {{lengthof projects}} projects... `);
    string queryValues;

    string[] jiraKeys = [];
    transaction with retries = 3, oncommit = onCommitJira, onabort = onAbortJira {
        int i = 0;
        foreach project in projects{
            sql:Parameter key = { sqlType: sql:TYPE_VARCHAR, value: project["key"].toString() };
            sql:Parameter name = { sqlType: sql:TYPE_VARCHAR, value: project["name"].toString() };
            sql:Parameter category = { sqlType: sql:TYPE_VARCHAR, value: project["category"].toString() };

            log:printDebug("Jira Project update starting for the key: " + project["key"].toString());

            var results = mysqlEP->update(QUERY_UPSERT_JIRA_PROJECT, key, name, category);
            match results {
                int c => {
                    log:printDebug(string `Upserting {{lengthof projects}} JiraProject. Return value {{c}}`);
                    if (c < 0) {
                        log:printError("Unable to Upsert to JiraProject ");
                        abort;
                    } else {
                        log:printDebug("Successful Upsert to JiraProject");
                    }
                }
                error e => {
                    //log:printError("Retrying to upsert to 'JiraProjects'", err = e);
                    retry;
                }
            }

            jiraKeys[i] = project["key"].toString();
            i++;
        }
    } onretry {
        log:printWarn("Retrying transaction to upsert to JiraProjects ");
    }

    string q = buildQueryFromTemplate("SELECT COUNT(*) as c FROM JiraProject WHERE jira_key IN <JIRA_KEY_LIST>",
        "<JIRA_KEY_LIST>", jiraKeys);
    var count = mysqlEP->select(q, RecordCount);
    int c = -1;

    match count {
        table tb => {
            while (tb.hasNext()) {
                match <RecordCount>tb.getNext() {
                    RecordCount rc => c = rc.c;
                    error e => log:printError("Unable to read inserted project count", err = e);
                }
            }
        }
        error e => log:printError("Unable to check inserted project count", err = e);
    }

    return lengthof jiraKeys == lengthof projects && c == lengthof jiraKeys;
}

function getJiraProjectDetailsFromJira() returns json[]|error {
    //Get JIRA Project details from JIRA API
    http:Request httpRequest = new;
    var jiraResponse = httpClientEP->get("/collector/jira/projects", request = httpRequest);
    match jiraResponse {
        http:Response resp => {
            json jsonResponse = resp.getJsonPayload() but {
                error e => log:printError("Error occurred while receiving Json payload.", err = e)
            };

            log:printDebug("Received JIRA Project details response: " + jsonResponse.toString());
            if (jsonResponse["success"].toString() == "true") {
                io:println(<json[]>jsonResponse[DATA_COLLECTOR_RESPONSE]);
                return <json[]>jsonResponse[DATA_COLLECTOR_RESPONSE];
            } else {
                log:printError("Found no records! Received error from Jira Service. Error: "
                        + jsonResponse["error"].toString());
                return <error>jsonResponse["error"];
            }
        }
        error e => {
            log:printError("Failed to fetch JIRA Project details from JIRA.", err = e);
            return e;
        }
    }
}

function getJiraKeysFromJira() returns string[]|error {
    //Get JIRA keys from JIRA API
    http:Request httpRequest = new;
    var jiraResponse = httpClientEP->get("/collector/jira/keys", request = httpRequest);
    match jiraResponse {
        http:Response resp => {
            json jsonResponse = resp.getJsonPayload() but {
                error e => log:printError("Error occurred while receiving Json payload.", err = e)
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
            log:printError("Failed to fetch JIRA keys from JIRA API.", err = e);
            return e;
        }
    }
}

function onCommitJira(string transactionId) {
    log:printInfo("Transaction comitted with transaction ID: " + transactionId);
}

function onAbortJira(string transactionId) {
    log:printInfo("Failed - aborted transaction with transaction ID: " + transactionId);
}