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

//TODO : finish after getAllJiraProjects() is finalized
function upsertToJiraProject(json[] projects) returns boolean|error {
    log:printDebug(string `Preparing Upsert query for {{lengthof projects}} projects... `);
    string queryValues;
    foreach project in projects{
        queryValues = queryValues + "," + "(" + "'" + project["key"].toString() + "'" + ","
            + "'"  + project["name"].toString() + "'" + ","
            + "'"  + project["category"].toString() + "'"  + ")";
    }

    queryValues = queryValues.replaceFirst(COMMA, EMPTY_STRING);
    string q = QUERY_BULK_UPSERT_JIRA_PROJECT.replace("<ENTRIES>", queryValues);
    log:printInfo("Record status bulk update: " + q);
    var results = mysqlEP->update(q);
    match results {
        int c => {
            log:printInfo(string `Inserted {{lengthof projects}} Jira Projects. Return value {{c}}`);
            if (c >= 0){
                return true;
            } else {
                return false;
            }
        }
        error e => {
            log:printError("Unable to insert record status", err = e);
            return e;
        }
    }
}

function getJiraProjectDetailsFromJira() returns json[]|error {
    //Get JIRA Project details from JIRA API
    http:Request httpRequest = new;
    var jiraResponse = httpClientEP->get("/collector/jira/projects", request = httpRequest);
    match jiraResponse {
        http:Response resp => {
            json jsonResponse = resp.getJsonPayload() but {
                error e => log:printError("Error occurred while receiving Json payload. Error: " + e.message)
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
            log:printError("Failed to fetch JIRA Project details from JIRA. Error: " + e.message);
            return e;
        }
    }
}