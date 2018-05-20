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

import ballerina/test;
import ballerina/io;
import ballerina/http;
import ballerina/log;

endpoint http:Client httpClient{
    url: "http://localhost:9000",
    timeoutMillis:300000
};

// Before Suite Function is used to start the services
@test:BeforeSuite
function beforeSuiteFunc() {
    boolean status = test:startServices(".");
    log:printInfo("Starting Services...");
}

// Test function
@test:Config
function testStartSalesforceService() {
    log:printInfo("testStartSalesforceService");

    http:Request httpRequest = new;
    var out = httpClient->post("/sync/salesforce/start", request = httpRequest);
    match out {
        http:Response resp => {
            log:printInfo("Response received from 'startSalesforceService' successfully!");
        }
        error e => {
            log:printError("Error occured! " + e.message);
            test:assertFail(msg = e.message);
        }
    }
}

@test:Config {
    dependsOn: ["testStartSalesforceService"]
}
//@test:Config
function testSyncSalesforceData() {
    log:printInfo("testSyncSalesforceData");

    http:Request httpRequest = new;
    var out = httpClient->post("/sync/salesforce", request = httpRequest);
    match out {
        http:Response resp => {
            log:printInfo("Response received from 'syncSalesforceData' successfully!");
        }
        error e => {
            log:printError("Error occured! " + e.message);
            test:assertFail(msg = e.message);
        }
    }
}

//@test:Config
//function testStartJiraService() {
//    log:printInfo("testStartJiraService");
//
//    http:Request httpRequest = new;
//    var out = httpClient->post("/sync/jira/start", request = httpRequest);
//    match out {
//        http:Response resp => {
//            log:printInfo("Response received from 'startJiraService' successfully!");
//        }
//        error e => {
//            log:printError("Error occured! " + e.message);
//            test:assertFail(msg = e.message);
//        }
//    }
//}

// After Suite Function is used to stop the services
@test:AfterSuite
function afterSuiteFunc() {
    test:stopServices(".");
}
