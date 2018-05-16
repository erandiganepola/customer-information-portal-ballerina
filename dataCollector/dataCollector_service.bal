//
// Copyright (c) 2018, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing,//
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//

import ballerina/http;
import ballerina/io;
import sfdc37 as sfdc;
import jira7 as jira;
import ballerina/log;
import ballerina/config;

endpoint sfdc:Client salesforceClientEP {
    clientConfig: {
        url: config:getAsString("SALESFORCE_ENDPOINT"),
        auth: {
            scheme: "oauth",
            accessToken: config:getAsString("SALESFORCE_ACCESS_TOKEN"),
            refreshToken: config:getAsString("SALESFORCE_REFRESH_TOKEN"),
            clientId: config:getAsString("SALESFORCE_CLIENT_ID"),
            clientSecret: config:getAsString("SALESFORCE_CLIENT_SECRET"),
            refreshUrl: config:getAsString("SALESFORCE_REFRESH_URL")
        }
    }
};

endpoint jira:Client jiraClientEP {
    clientConfig: {
        url: config:getAsString("JIRA_ENDPOINT"),
        auth: {
            scheme: "basic",
            username: config:getAsString("JIRA_USERNAME"),
            password: config:getAsString("JIRA_PASSWORD")
        }
    }
};

endpoint http:Listener listener {
    port: config:getAsInt("DATA_COLLECTOR_HTTP_PORT")
};

@http:ServiceConfig {
    endpoints: [listener],
    basePath: "/collector"
}
service<http:Service> dataCollector bind listener {

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/salesforce"
    }
    getDataFromSF(endpoint caller, http:Request request) {

        http:Response response = new;

        var payloadIn = request.getJsonPayload();
        match payloadIn {
            error e => setErrorPayload(response, e);
            json jiraKeys => {
                match fetchSalesforceData(jiraKeys) {
                    sfdc:SalesforceConnectorError e => setErrorPayload(response, e);
                    json sfResponse => {
                        match <json[]>sfResponse[RECORDS]{
                            error e => setErrorPayload(response, e);
                            json[] records => {
                                boolean flag_paginationError = false;
                                string nextRecordsUrl = sfResponse[NEXT_RECORDS_URL].toString();
                                while (nextRecordsUrl != NULL) { //if the salesforce response is paginated
                                    int i = lengthof records;
                                    log:printDebug("nextRecodsUrl is recieved: " + nextRecordsUrl);
                                    match fetchSalesforceData(nextRecordsUrl) {
                                        sfdc:SalesforceConnectorError e => {
                                            setErrorPayload(response, e);
                                            nextRecordsUrl = EMPTY_STRING;
                                            flag_paginationError = true;
                                        }
                                        json sfResponse => {
                                            match <json[]>sfResponse[RECORDS]{
                                                json[] nextRecords => {
                                                    foreach item in nextRecords{
                                                        records[i] = item;
                                                        i++;
                                                    }
                                                    nextRecordsUrl = sfResponse[NEXT_RECORDS_URL].toString();
                                                }
                                                error e => {
                                                    setErrorPayload(response, e);
                                                    nextRecordsUrl = EMPTY_STRING;
                                                    flag_paginationError = true;
                                                }
                                            }
                                        }
                                    }
                                }
                                log:printDebug("number of salesforce records recieved: " + <string>(lengthof records));
                                if (flag_paginationError==false){
                                    response.setJsonPayload({ "success": true, "response": records, "error": null });
                                }
                            }
                        }
                    }
                }
            }
        }

        caller->respond(response) but {
            error e => log:printError("Error when responding", err = e)
        };
    }


    @http:ResourceConfig {
        methods: ["GET"],
        path: "/jira/keys"
    }
    getAllJiraKeys(endpoint caller, http:Request request) {

        http:Response response = new;

        var queryParams = request.getQueryParams();
        string excludeTypes;
        try{
            excludeTypes = queryParams["exclude"];
        }
        catch(error e){
            log:printDebug("no query parameters found with key 'exclude'");
            excludeTypes = EMPTY_STRING;
        }
        var connectorResponse = jiraClientEP->getAllProjectSummaries();
        match connectorResponse {
            jira:ProjectSummary[] summaryList => {
                json[] projectKeys = [];
                int i = 0;

                if(excludeTypes=="closed"){
                    foreach (project in summaryList){
                        if (!project.name.hasPrefix("ZZZ")){
                            projectKeys[i] = project.key;
                            i++;
                        }
                    }
                    log:printDebug(<string>(lengthof projectKeys) + " keys were fetched from jira successfully");
                } else {
                    foreach (project in summaryList){
                        projectKeys[i] = project.key;
                        i++;
                    }
                    log:printDebug(<string>(lengthof projectKeys) + " keys were fetched from jira successfully");
                }
                response.setJsonPayload({ "success": true, "response": projectKeys, "error": null });
            }
            jira:JiraConnectorError e => response.setJsonPayload({ "success": false, "response": null, "error": e.
                message });
        }
        caller->respond(response) but { error e => log:printError("Error when responding", err = e) };
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/jira/projects"
    }
    getAllJiraProjects(endpoint caller, http:Request request) {

        http:Response response = new;

        var connectorResponse = jiraClientEP->getAllProjectSummaries();
        match connectorResponse {
            jira:ProjectSummary[] summaryList => {
                response.setJsonPayload({ "success": true, "response": check <json>summaryList, "error": null });
            }
            jira:JiraConnectorError e => response.setJsonPayload({ "success": false, "response": null, "error": e.
                message });
        }
        caller->respond(response) but { error e => log:printError("Error when responding", err = e) };
    }
}
