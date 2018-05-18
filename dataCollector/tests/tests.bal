import ballerina/test;
import ballerina/io;
import ballerina/http;
import ballerina/log;
import balerina/config;

endpoint http:Client httpClientEP{
    url: config:getAsString("DATA_COLLECTOR_URI"), timeoutMillis:300000
};

json test_jiraKeyList;
string test_nextRecordsUrl;

// Before Suite Function is used to start the service
@test:BeforeSuite
function beforeSuiteFunc() {
    boolean status = test:startServices("dataCollector");
}

// Test function to check the
@test:Config
function test_getAllJiraKeys() {
    log:printInfo("test_service_getAllJiraKeys()");

    http:Request httpRequest = new;
    var out = httpClientEP->get(DATA_COLLECTOR_SERVICE_BASE_PATH + DATA_COLLECTOR_JIRA_KEYS_RESOURCE, request =
        httpRequest);
    match out {
        http:Response resp => {
            json dcResponse = check resp.getJsonPayload();
            if (dcResponse["success"].toString() == "true"){
                test_jiraKeyList = dcResponse["response"];

            } else {
                test:assertFail(msg = dcResponse["error"].toString());
            }
        }
        error e => {
            test:assertFail(msg = e.message);
        }
    }
}

// Test function
@test:Config
function test_getAllJiraProjects() {
    log:printInfo("test_service_getAllJiraProjects()");

    http:Request httpRequest = new;
    var out = httpClientEP->get(DATA_COLLECTOR_SERVICE_BASE_PATH + DATA_COLLECTOR_JIRA_PROJECTS_RESOURCE, request =
        httpRequest);
    match out {
        http:Response resp => {
            json dcResponse = check resp.getJsonPayload();
            if (dcResponse["success"].toString() == "true"){
            } else {
                test:assertFail(msg = dcResponse["error"].toString());
            }
        }
        error e => {
            test:assertFail(msg = e.message);
        }
    }
}

// Test function
@test:Config {
    dependsOn: ["test_getAllJiraKeys"]
}
function test_getDataFromSF() {

    log:printInfo("test_service_getDataFromSF");

    http:Request httpRequest = new;
    json jirakeys = ["AAALIFEPROD", "CINECADEVSVC", "TRIMBLEINTERNAL", "IBMCOGNOSOEMSPRT", "IBMFILENETSESSPRT"];

    httpRequest.setJsonPayload(jirakeys);
    var out = httpClientEP->post(DATA_COLLECTOR_SERVICE_BASE_PATH + DATA_COLLECTOR_SALESFORCE_RESOURCE, request =
        httpRequest);
    match out {
        http:Response resp => {
            json dcResponse = check resp.getJsonPayload();
            if (dcResponse["success"].toString() == "false") {
                test:assertFail(msg = dcResponse["error"].toString());
            }
        }
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
