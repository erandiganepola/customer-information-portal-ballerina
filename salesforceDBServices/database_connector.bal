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
import ballerina/jdbc;

endpoint jdbc:Client salesforceDB {
    url: "jdbc:mysql://localhost:3306/test_cip",
    username: "root",
    password: "root",
    poolOptions: { maximumPoolSize: 5 }
};

endpoint http:Listener listener {
    port: 9091
};

@http:ServiceConfig {
    endpoints: [listener],
    basePath: "/salesforceDatabase"
}
service<http:Service> sfDatabaseService bind listener {

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/"
    }
    getDataFromJiraKey(endpoint caller, http:Request request) {
        http:Response response = new;
        table dt;

        match request.getJsonPayload() {
            json jsonQuery => {
                string stringQuery = jsonQuery.toString();
                var selectRet = salesforceDB->select(stringQuery, ());
                match selectRet {
                    table tableReturned => dt = tableReturned;
                    error e => io:println("Select data from student table failed: " + e.message);
                }
            }
            error e => {
                response.setJsonPayload({ "success": false, "response": null, "error": e.message });
            }
        }
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/"
    }
    getDetailsByJiraKey(endpoint caller, http:Request request) {
        http:Response response = new;

        match request.getJsonPayload() {
            json jsonQuery => {
                string stringQuery = jsonQuery.toString();

                var selectRet = salesforceDB->select(stringQuery, Account);
                table<Account> account;
                match selectRet {
                    table tableReturned => dt = tableReturned;
                    error e => io:println("Select data from student table failed: " + e.message);
                }
            }
            error e => {
                response.setJsonPayload({ "success": false, "response": null, "error": e.message });
            }
        }
    }
}

