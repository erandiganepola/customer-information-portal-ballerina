import ballerina/test;

@test:Config
function test_Connector() {

    SalesforceDatabaseConnector sfdbConnector = new();

    var result = sfdbConnector.getAllCustomerDetailsByJiraKeys(["AAALIFEPROD", "AAAMAPROD"]);

}