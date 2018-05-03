import ballerina/test;
import ballerina/io;
import ballerina/http;
import ballerina/log;

endpoint http:Client httpClientEP{
    url: "http://localhost:9090"
};

// Before Suite Function is used to start the services
@test:BeforeSuite
function beforeSuiteFunc() {
    boolean status = test:startServices("dataCollector");
    io:println(status);
}

// Test function
@test:Config
function test_dataCollectorSF() {
    io:println("\n\n\n\n\n");
    log:printInfo("test_service_salesforceDataCollector");

    json jsonKeyList = ["AAALIFEPROD", "AAAMAPROD"];

    http:Request httpRequest = new;
    httpRequest.setJsonPayload(jsonKeyList);
    var out = httpClientEP->post("/collector/salesforce/", request = httpRequest);
    match out {
        http:Response resp => io:println(resp.getJsonPayload());
        error e => {
            test:assertFail(msg = e.message);
        }
    }
}

// Test function
@test:Config
function test_getActiveJiraKeys() {
   io:println("\n\n\n\n\n");
    log:printInfo("test_service_getActiveJiraKeys()");

    http:Request httpRequest = new;
    var out = httpClientEP->get("/collector/jira/keys", request = httpRequest);
    match out {
        http:Response resp => io:println(resp.getJsonPayload()!toString());
        error e => {
            test:assertFail(msg = e.message);
        }
    }
}

@test:Config
function test_categorizeJiraKeys() {
    io:println("\n\n\n\n\n");
    log:printInfo("test_function_categorieJiraKeys()");

    string[] newKeys = ["KEY1","KEY2"];
    string[] currentKeys = ["KEY2","KEY3"];

    map result = categorizeJiraKeys(newKeys, currentKeys);
    io:println(result);
}

// After Suite Function is used to stop the services
@test:AfterSuite
function afterSuiteFunc() {
    test:stopServices("dataCollector");
}
