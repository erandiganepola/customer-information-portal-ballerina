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
function upsertToJiraProject() returns boolean|error {
    string[] projects = [];
    foreach project in projects{
        return true;
    }
}

function getJiraProjectDetailsFromJira() returns string[]|error {
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
                io:println("Json response start");
                io:println(<json[]>jsonResponse[DATA_COLLECTOR_RESPONSE]);
                io:println("Json response end");
                return <string[]>jsonResponse[DATA_COLLECTOR_RESPONSE];
            } else {
                string[] projectDetails = [];
                log:printDebug("Found no details for received response of Jira Project details!");
                return projectDetails;
            }
        }
        error e => {
            log:printError("Failed to fetch JIRA Project details from JIRA. Error: " + e.message);
            return e;
        }
    }
}