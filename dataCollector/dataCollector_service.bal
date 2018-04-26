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

import ballerina/http;
import ballerina/io;
import sfdc;
import jira7 as jira;
import ballerina/log;
import ballerina/config;

endpoint sfdc:Client salesforceClientEP {
    baseUrl: "https://wso2--wsbox.cs8.my.salesforce.com",
    clientConfig: {
        auth: {
            scheme: "oauth",
            accessToken:
            "00DL0000002ASPS!ASAAQNEFTkjpHA8irToqWJXOjxMV7e6T3q_SiL4EILcqVPmCybHx85R5bAQQTfuJ8eKG13wRhEVowZOexsJOrNgWG41MgHrV"
            ,
            refreshToken: "",
            clientId: "",
            clientSecret: "",
            refreshUrl: ""
        }
    }
};

endpoint jira:Client jiraClientEP {
    clientConfig: {
        url: "https://support-staging.wso2.com/jira",
        auth: {
            scheme: "basic",
            username: config:getAsString("jira_username"),
            password: config:getAsString("jira_password")
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
                io:println(projectKeys);
                io:println(i);
            }
            jira:JiraConnectorError e => response.setJsonPayload({ "success": false, "response": null });
        }
        _ = caller->respond(response);
    }
}
