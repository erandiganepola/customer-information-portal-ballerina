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
            error e => setErrorResponse(response, e);
            json jiraKeys => {
                match fetchSalesforceData(jiraKeys) {
                    sfdc:SalesforceConnectorError e => setErrorResponse(response, e);
                    json sfResponse => {
                        match <json[]>sfResponse[RECORDS]{
                            error e => setErrorResponse(response, e);
                            json[] records => {
                                boolean flag_paginationError = false;
                                string nextRecordsUrl = sfResponse[NEXT_RECORDS_URL].toString();
                                while (nextRecordsUrl != NULL) { //if the salesforce response is paginated
                                    int i = lengthof records;
                                    log:printDebug("nextRecodsUrl is recieved: " + nextRecordsUrl);
                                    match fetchSalesforceData(nextRecordsUrl) {
                                        sfdc:SalesforceConnectorError e => {
                                            setErrorResponse(response, e);
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
                                                    setErrorResponse(response, e);
                                                    nextRecordsUrl = EMPTY_STRING;
                                                    flag_paginationError = true;
                                                }
                                            }
                                        }
                                    }
                                }

                                if (flag_paginationError == false){
                                    log:printDebug( <string>(lengthof records) + "records were fetched from salesforce successfully" );
                                    setSuccessResponse(response,records);
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

        var queryParams = request.getQueryParams();  //extracts query paramters from the resource URI
        string excludeProjectTypes;
        try {
            excludeProjectTypes = queryParams["exclude"];
        }
        catch (error e){
            log: printDebug("no query parameters found with key 'exclude'");
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
                setSuccessResponse(response,projectKeys);
            }
            jira:JiraConnectorError e => setErrorResponse(response,e);
        }
        io:println(response.getJsonPayload());
        caller->respond(response) but {
            error e => log:printError("Error when responding", err = e)
        };
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
                json jsonSummaryList =  check <json>summaryList;
                io:println(<json[]>jsonSummaryList);
                setSuccessResponse(response,jsonSummaryList);
            }
            jira:JiraConnectorError e => setErrorResponse(response,e);
        }
        caller->respond(response) but { error e => log:printError("Error when responding", err = e) };
    }
}
