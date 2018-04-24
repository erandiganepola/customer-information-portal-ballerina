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
import ballerina/log;

endpoint sfdc:Client salesforceClientEP {
    baseUrl:"https://wso2--wsbox.cs8.my.salesforce.com",
    clientConfig:{
        auth:{
            scheme:"oauth",
            accessToken:
            "00DL0000002ASPS!ASAAQNEFTkjpHA8irToqWJXOjxMV7e6T3q_SiL4EILcqVPmCybHx85R5bAQQTfuJ8eKG13wRhEVowZOexsJOrNgWG41MgHrV"
            ,
            refreshToken:"",
            clientId:"erandisf@wso2.com",
            clientSecret:"salesforce123",
            refreshUrl:""
        }
    }
};
endpoint http:Listener listener {
    port:9090
};
@http:ServiceConfig {
    endpoints:[listener],
    basePath:"/collector"
}
service<http:Service> dataCollector bind listener {

    @http:ResourceConfig {
        methods:["POST"],
        path:"/SF"
    }
    fetchDataFromSF(endpoint caller, http:Request request) {

        json jiraKeyList = request.getJsonPayload() but {http:PayloadError => null};

        string query_string = buildQueryFromTemplate(QUERY_TEMPLATE_GET_ACCOUNT_DETAILS_BY_JIRA_KEY, jiraKeyList);
        http:Response response = new;
        var connectorResponse = salesforceClientEP->getQueryResult(query_string);

        match connectorResponse{
            json jsonResponse => {
                io:println(jsonResponse);
                response.setJsonPayload({"success":true, "response":jsonResponse});
            }
            sfdc:SalesforceConnectorError => response.setJsonPayload({"sucess":false, "response":null});
        }

        _ = caller->respond(response);
    }
}