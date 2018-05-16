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
            json jiraKeys => {
                json sfResponse = fetchSalesforceData(jiraKeys);

                if (sfResponse["success"].toString() == FALSE){
                    response.setJsonPayload(sfResponse);
                }
                else {
                    match <json[]>sfResponse["response"]["records"]{ //casting json response to a json array
                        json[] records => {
                            boolean flag=true;
                            string nextRecordsUrl = sfResponse["response"]["nextRecordsUrl"].toString();
                            while (nextRecordsUrl != NULL) { //if the salesforce response is paginated
                                int i = lengthof records;
                                log:printDebug("nextRecodsUrl is recieved: "+ nextRecordsUrl);
                                sfResponse = fetchSalesforceData(nextRecordsUrl);
                                match <json[]>sfResponse["response"]["records"]{
                                    json[] nextRecords => {
                                        foreach item in nextRecords{
                                            records[i] = item;
                                            i++;
                                        }
                                        nextRecordsUrl = sfResponse["response"]["nextRecordsUrl"].toString();
                                    }
                                    error e => {
                                        response.setJsonPayload({ "success": false, "response": null, "error": e.message });
                                        nextRecordsUrl = "";
                                        flag = false;
                                    }
                                }
                            }
                            log:printDebug("number of salesforce records recieved: "+ <string>(lengthof records));
                            if(flag){
                                response.setJsonPayload({ "success": true, "response": records, "error": null });
                            }
                        }
                        error e => response.setJsonPayload({ "success": false, "response": null, "error": e.message });
                    }
                }
            }
            error e => response.setJsonPayload({ "success": false, "response": null, "error": e.message });
        }
        _ = caller->respond(response);
    }



    @http:ResourceConfig {
        methods: ["GET"],
        path: "/jira/keys?exclude=closed"
    }
    getActiveJiraKeys(endpoint caller, http:Request request) {

        http:Response response = new;

        var connectorResponse = jiraClientEP->getAllProjectSummaries();
        match connectorResponse {
            jira:ProjectSummary[] summaryList => {
                json[] projectKeys = [];
                int i = 0;
                foreach (project in summaryList){
                    if (!project.name.hasPrefix("ZZZ")){
                        projectKeys[i] = project.key;
                        i++;
                    }
                }
                response.setJsonPayload({ "success": true, "response": projectKeys, "error": null });
            }
            jira:JiraConnectorError e => response.setJsonPayload({ "success": false, "response": null, "error": e.
                message });
        }
        _ = caller->respond(response);
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/jira/keys"
    }
    getAllJiraKeys(endpoint caller, http:Request request) {

        http:Response response = new;

        var connectorResponse = jiraClientEP->getAllProjectSummaries();
        match connectorResponse {
            jira:ProjectSummary[] summaryList => {
                json[] projectKeys = [];
                int i = 0;
                foreach (project in summaryList){
                    projectKeys[i] = project.key;
                    i++;
                }
                response.setJsonPayload({ "success": true, "response": projectKeys, "error": null });
            }
            jira:JiraConnectorError e => response.setJsonPayload({ "success": false, "response": null, "error": e.
                message });
        }
        _ = caller->respond(response);
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
        _ = caller->respond(response);
    }
}
