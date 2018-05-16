import ballerina/test;
import ballerina/io;

SalesforceDatabaseConnector sfdbConnector;

@test:BeforeSuite
function beforeSuiteFunc() {
    sfdbConnector = new();
}

@test:Config
function test_getCustomerDetailsByJiraKeys() {

    var connectorResponse = sfdbConnector.getCustomerDetailsByJiraKeys(["AAALIFEPROD", "AAAMAPROD"]);
    match connectorResponse {
        error e => test:assertFail(msg = e.message);
        json[] => {}
    }
}

@test:Config
function test_getProjectDetailsByJiraKeys() {

    var connectorResponse = sfdbConnector.getProjectDetailsByJiraKeys(["AAALIFEPROD", "AAAMAPROD"]);
    match connectorResponse {
        error e => test:assertFail(msg = e.message);
        json[] => {}
    }
}

@test:Config
function test_searchForKeys() {
    SalesforceDatabaseConnector sfdbConnector = new();
    var connectorResponse = sfdbConnector.searchForKeys("XXX");
    match connectorResponse {
        error e => test:assertFail(msg = e.message);
        json[] records => {
            io:println(records);
        }
    }
}