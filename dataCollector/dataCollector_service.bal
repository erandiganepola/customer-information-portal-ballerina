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

//client endpoint of salesforce connector
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

//client endpoint of jira connector
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
    basePath: DATA_COLLECTOR_SERVICE_BASE_PATH
}
service<http:Service> dataCollector bind listener {

    @http:ResourceConfig {
        methods: ["POST"],
        path: DATA_COLLECTOR_SALESFORCE_RESOURCE
    }
    getDataFromSF(endpoint caller, http:Request request) {

        http:Response response = new;

        var payloadIn = request.getJsonPayload();
        //extract jira key list from the json payload of the HTTP request
        match payloadIn {
            error e => setErrorResponse(response, e);
            json jiraKeys => {
                match fetchSalesforceData(jiraKeys) {
                    sfdc:SalesforceConnectorError e => setErrorResponse(response, e);
                    json sfResponse => {
                        if (hasPaginatedData(sfResponse) == false){
                            match <json[]>sfResponse[RECORDS]{
                                error e => setErrorResponse(response, e);
                                json[] records => {
                                    log:printDebug(<string>(lengthof records) +
                                            "records were fetched from salesforce successfully");
                                    setSuccessResponse(response, records);
                                }
                            }
                        } else {
                            match fetchPaginatedDataFromSalesforce(sfResponse) {
                                json[] records => {
                                    log:printDebug(<string>(lengthof records) +
                                            "records were fetched from salesforce successfully");
                                    setSuccessResponse(response, records);
                                }
                                error|sfdc:SalesforceConnectorError e => setErrorResponse(response, e);
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
        path: DATA_COLLECTOR_JIRA_KEYS_RESOURCE
    }
    getAllJiraKeys(endpoint caller, http:Request request) {

        http:Response response = new;

        //extracts query paramters from the resource URI
        var queryParams = request.getQueryParams();
        string excludeProjectTypes;
        try {
            excludeProjectTypes = queryParams["exclude"];
        }
        catch (error e){
            log:
            printDebug("no query parameters found with key 'exclude'.Fetching all jira projects..");
            excludeProjectTypes = EMPTY_STRING;
        }
        var connectorResponse = jiraClientEP->getAllProjectSummaries();
        match connectorResponse {
            jira:ProjectSummary[] summaryList => {
                json[] projectKeys = [];
                int i = 0;
                if (excludeProjectTypes == "closed"){
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
                setSuccessResponse(response, projectKeys);
            }
            jira:JiraConnectorError e => setErrorResponse(response, e);
        }

        caller->respond(response) but {
            error e => log:printError("Error when responding", err = e)
        };
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: DATA_COLLECTOR_JIRA_PROJECTS_RESOURCE
    }
    getAllJiraProjects(endpoint caller, http:Request request) {

        http:Response response = new;
        var connectorResponse = jiraClientEP->getAllProjectSummaries();
        match connectorResponse {
            jira:ProjectSummary[] summaryList => {
                json[] jsonSummaryList = projectSummaryToJson(summaryList);
                setSuccessResponse(response, jsonSummaryList);
            }
            jira:JiraConnectorError e => setErrorResponse(response, e);
        }

        caller->respond(response) but {
            error e => log:printError("Error when responding", err = e)
        };
    }
}