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
    boolean status = test:startServices("Starting Database Services...");
    io:println(status);
}

// Test function
@test:Config
function testStartSyncData() {
    log:printInfo("testStartSyncData Service");

    http:Request httpRequest = new;
    var out = httpClient->post("/sync/salesforce/start", request = httpRequest);
    match out {
        //http:Response resp => io:println(check resp.getJsonPayload());
        http:Response resp => io:println("hello");
        error e => {
            test:assertFail(msg = e.message);
        }
    }
}

// After Suite Function is used to stop the services
@test:AfterSuite
function afterSuiteFunc() {
    test:stopServices("Stopping Database Services...");
}
