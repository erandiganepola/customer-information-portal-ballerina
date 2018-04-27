import ballerina/test;
import ballerina/io;
import ballerina/http;

// Before Suite Function is used to start the services
@test:BeforeSuite
function beforeSuiteFunc() {
    boolean status = test:startServices("dataCollector");
    io:println(status);
}

//// Test function
//@test:Config
//function test_dataCollectorSF() {
//    endpoint http:Client httpClientEP{
//        url: "http://localhost:9090"
//    };
//    json jsonKeyList = ["AAALIFEPROD", "AAAMAPROD"];
//
//    http:Request httpRequest = new;
//    httpRequest.setJsonPayload(jsonKeyList);
//    var out = httpClientEP->post("/collector/salesforce/", request = httpRequest);
//    match out {
//        http:Response resp => io:println(resp.getJsonPayload());
//        error e => {
//            test:assertFail(msg = e.message);
//        }
//    }
//}

// Test function
@test:Config
function test_getActiveJiraKeys() {
    endpoint http:Client httpClientEP{
        url: "http://localhost:9090"
    };

    http:Request httpRequest = new;
    var out = httpClientEP->get("/collector/jira/keys", request = httpRequest);
    match out {
        http:Response resp => io:println(resp.getJsonPayload());
        error e => {
            test:assertFail(msg = e.message);
        }
    }
}

// After Suite Function is used to stop the services
@test:AfterSuite
function afterSuiteFunc() {
    test:stopServices("dataCollector");
}
