import ballerina/test;
import ballerina/io;

@test:Config
function test_getCustomerDetailsByJiraKeys() {
    SalesforceDatabaseConnector sfdbConnector = new();
    match sfdbConnector.getCustomerDetailsByJiraKeys(["AAALIFEPROD", "AAAMAPROD"]) {
        error e => test:assertFail(msg = e.message);
        json[] => {}
    }
}

@test:Config
function test_getProjectDetailsByJiraKeys() {
    SalesforceDatabaseConnector sfdbConnector = new();
    match sfdbConnector.getProjectDetailsByJiraKeys(["AAALIFEPROD", "AAAMAPROD"]) {
        error e => test:assertFail(msg = e.message);
        json[] => {}
    }
}