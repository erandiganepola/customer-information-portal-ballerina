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
    clientConfig:{
        url:config:getAsString("SALESFORCE_ENDPOINT"),
        auth:{
            scheme:"oauth",
            accessToken:config:getAsString("SALESFORCE_ACCESS_TOKEN"),
            refreshToken:config:getAsString("SALESFORCE_REFRESH_TOKEN"),
            clientId:config:getAsString("SALESFORCE_CLIENT_ID"),
            clientSecret:config:getAsString("SALESFORCE_CLIENT_SECRET"),
            refreshUrl:config:getAsString("SALESFORCE_REFRESH_URL")
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
    port: 9090
};

@http:ServiceConfig {
    endpoints: [listener],
    basePath: "/collector"
}
service<http:Service> realtimeCollector bind listener {

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/salesforce"
    }
    getDataFromSF(endpoint caller, http:Request request) {

        http:Response response = new;

        var payloadIn = request.getJsonPayload();
        match payloadIn {
            json jiraKeys => response.setJsonPayload(fetchSalesforceData(jiraKeys));
            error => response.setJsonPayload({ "success": false, "response": null });
        }
        _ = caller->respond(response);
    }

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/salesforce/next"
    }
    getPaginatedDataFromSF(endpoint caller, http:Request request) {

        http:Response response = new;

        var payloadIn = request.getJsonPayload();
        match payloadIn {
            json nextRecordUrl => response.setJsonPayload(fetchSalesforceData(nextRecordUrl.toString()));
            error => response.setJsonPayload({ "success": false, "response": null });
        }
        _ = caller->respond(response);
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/jira/keys"
    }
    getActiveJiraKeys(endpoint caller, http:Request request) {

        http:Response response = new;

        var connectorResponse = jiraClientEP->getAllProjectSummaries();
        match connectorResponse {
            jira:ProjectSummary[] summaryList => {

                json[] projectKeys = [];
                int i = 0;
                foreach (project in summaryList){
                    if(!project.name.hasPrefix("ZZZ")){
                        projectKeys[i]=project.key;
                        i+=1;
                    }
                }
                response.setJsonPayload(projectKeys);
            }
            jira:JiraConnectorError e => response.setJsonPayload({ "success": false, "response": null });
        }
        _ = caller->respond(response);
    }
}
