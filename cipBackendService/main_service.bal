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
import sfdbConnector;


endpoint http:Listener listener {
    port: 9001
};

@http:ServiceConfig {
    endpoints: [listener],
    basePath: "cip/server"
}
service<http:Service> CIPService bind listener {

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/search/jira"
    }
    getJiraProjectMatches(endpoint caller, http:Request request) {

        http:Response response = new;

        //extracts query paramters from the resource URI
        var queryParams = request.getQueryParams();
        string pattern = "";
        try {
            pattern = queryParams["pattern"];
        }
        catch (error e){
            log:printError("no query parameters found with key 'pattern'");
        }

        if (pattern != ""){
            sfdbConnector:SalesforceDatabaseConnector sfdbConnector = new;
            response.setJsonPayload(check sfdbConnector.searchForKeys(pattern));
        }
        caller->respond(response) but {
            error e => log:printError("Error when responding", err = e)
        };
    }
}

