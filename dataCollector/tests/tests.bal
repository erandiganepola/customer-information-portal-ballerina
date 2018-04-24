import ballerina/test;
import ballerina/io;
import ballerina/http;

// Before Suite Function is used to start the services
@test:BeforeSuite
function beforeSuiteFunc() {
    boolean status = test:startServices("dataCollector");
    io:println(status);
}

// Test function
@test:Config
function test_dataCollectorSF() {
    endpoint http:Client httpClientEP{
        url:"http://localhost:9090"
    };
    json jsonKeyList = ["AAALIFEPROD","AAAMAPROD"];
    http:Request httpRequest = new;
    httpRequest.setJsonPayload(jsonKeyList);
    var out = httpClientEP->post("/collector/SF", request = httpRequest);
    match out{
        http:Response resp => io:println(resp.getJsonPayload());
        http:HttpConnectorError e => {
            test:assertFail(msg=e.message);
        }
    }
}

// After Suite Function is used to stop the services
@test:AfterSuite
function afterSuiteFunc() {
    test:stopServices("dataCollector");
}
