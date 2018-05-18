import ballerina/test;
import ballerina/io;
import ballerina/http;
import ballerina/log;

endpoint http:Client httpClient{
    url: "http://localhost:9000"
};

// Before Suite Function is used to start the services
@test:BeforeSuite
function beforeSuiteFunc() {
    boolean status = test:startServices(".");
    log:printInfo("Starting Services...");
}

// Test function
//@test:Config
//function testStartSalesforceService() {
//    log:printInfo("testStartSalesforceService");
//
//    http:Request httpRequest = new;
//    var out = httpClient->post("/sync/salesforce/start", request = httpRequest);
//    match out {
//        http:Response resp => {
//            log:printInfo("Response received from 'startSalesforceService' successfully!");
//        }
//        error e => {
//            log:printError("Error occured! " + e.message);
//            test:assertFail(msg = e.message);
//        }
//    }
//}
//
//@test:Config {
//    dependsOn: ["testStartSalesforceService"]
//}
////@test:Config
//function testSyncSalesforceData() {
//    log:printInfo("testSyncSalesforceData");
//
//    http:Request httpRequest = new;
//    var out = httpClient->post("/sync/salesforce", request = httpRequest);
//    match out {
//        http:Response resp => {
//            log:printInfo("Response received from 'syncSalesforceData' successfully!");
//        }
//        error e => {
//            log:printError("Error occured! " + e.message);
//            test:assertFail(msg = e.message);
//        }
//    }
//}

@test:Config
function testStartJiraService() {
    log:printInfo("testStartJiraService");

    http:Request httpRequest = new;
    var out = httpClient->post("/sync/jira/start", request = httpRequest);
    match out {
        http:Response resp => {
            log:printInfo("Response received from 'startJiraService' successfully!");
        }
        error e => {
            log:printError("Error occured! " + e.message);
            test:assertFail(msg = e.message);
        }
    }
}

// After Suite Function is used to stop the services
@test:AfterSuite
function afterSuiteFunc() {
    test:stopServices(".");
}
