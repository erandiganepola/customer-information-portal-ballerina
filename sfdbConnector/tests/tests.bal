import ballerina/test;

@test:Config
function test_getAllCustomerDetailsByJiraKeys() {

    SalesforceDatabaseConnector sfdbConnector = new();
    var result = sfdbConnector.getAllCustomerDetailsByJiraKeys(["AAALIFEPROD", "AAAMAPROD"]);

}

@test:Config
function test_getProjectDetailsByJiraKeys() {

    SalesforceDatabaseConnector sfdbConnector = new();
    var result = sfdbConnector.getProjectDetailsByJiraKeys(["AAALIFEPROD", "AAAMAPROD"]);

}