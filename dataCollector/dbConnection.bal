import ballerina/mysql;
import ballerina/io;

string key = "AAALIFEPROD";
string name = "ABC";
string profile = "XYZ";
int count = 4;
string deployment = "";
string customerName = "ABCD";
string customerType = "";
string classification = "";
string account_owner = "";
string technical_owner = "";
string domain = "";
string primary_contact = "";
string timezone = "";

endpoint mysql:Client mysqlEP {
    host:"localhost",
    port:3306,
    name:"test_cip",
    username:"root",
    password:"root",
    poolOptions:{maximumPoolSize:5}
};

endpoint sfdc:Client salesforceClientEP {
    baseUrl:"https://wso2--wsbox.cs8.my.salesforce.com",
    clientConfig:{
        auth:{
            scheme:"oauth",
            accessToken:
            "00DL0000002ASPS!ASAAQNEFTkjpHA8irToqWJXOjxMV7e6T3q_SiL4EILcqVPmCybHx85R5bAQQTfuJ8eKG13wRhEVowZOexsJOrNgWG41MgHrV"
            ,
            refreshToken:"",
            clientId:"",
            clientSecret:"",
            refreshUrl:""
        }
    }
};

function main(string... args) {
    map< string[] > keys = {"toBeDeleted":["AAALIFEPROD", "AAAMAPROD"], "toBeUpserted":["AAALIFEPROD", "AAAMAPROD"]};
    io:println(keys);
    doTransaction(keys);
}

function query(string[] jiraKeys) returns json[] {
    string SOQuery = buildQueryFromTemplate(QUERY_TEMPLATE_GET_ACCOUNT_DETAILS_BY_JIRA_KEY, jiraKeys);
    var connectorResponse = salesforceClientEP -> getQueryResult(SOQuery);
    json[] records;
    match connectorResponse {
        json jsonResponse => {
            io:println(jsonResponse);
            records = check < json[]>jsonResponse.records;
            return records;
        }
        sfdc:SalesforceConnectorError e => return [];
    }
}

function doTransaction(map jiraKeys) {
    int|error result;
    string[] toBeDeleted = check < string[]>jiraKeys["toBeDeleted"];
    string[] toBeUpserted = check < string[]>jiraKeys["toBeUpserted"];

    json[] toUpsert = query(toBeUpserted);

    transaction with retries = 4, oncommit = onCommitFunction, onabort = onAbortFunction {
        // Get Opportunity Ids by jira keys
        "SELECT opportunity_id FROM SupportAccount WHERE jira_key in <JIRA_KEY_LIST>";
        string[] opportunityIds = [];

        // Out of those Opportunity Ids, find which are not used in other Support Accounts
        "SELECT opportunity_id FROM SupportAccount WHERE opportunity_id IN <IDS> GROUP BY opportunity_id
        HAVING count(opportunity_id)=1";
        string[] newOpportunityIds = [];

        // Get Account Ids to be deleted
        "SELECT account_id FROM Opportunity WHERE opportunity_id IN <IDS>";
        string[] accountIds = [];

        // Find account Ids, that don't have other opportunities.
        "SELECT account_id FROM Opportunity WHERE account_id IN <IDS> GROUP BY account_id
        HAVING count(account_id)=1";
        string[] newAccountIds = [];


        result = mysqlEP -> update(buildQueryFromTemplateString(
                                       "DELETE FROM SupportAccount where jira_key IN <JIRA_KEY_LIST>", toBeDeleted));
        "DELETE FROM Account WHERE account_id IN <IDS>";
        "DELETE FROM Opportunity WHERE opportunity_id IN <IDS>";
        // Can do this with "ON DELETE CASCADE"
        "DELETE FROM OpportunityProducts WHERE opportunity_id IN <IDS>";

        match result {
            int c => {
                // The transaction can be force aborted using the `abort` keyword at any time.
                if (c == 0) {
                    abort;
                }
            }
            error err => {
                // The transaction can be force retried using `retry` keyword at any time.
                io:println(err);
                retry;
            }
        }

        foreach upsertKey in toBeUpserted {
            // START TRANSACTION
            result = mysqlEP -> update("INSERT INTO Opportunity_Products
                                            (JIRA_key, Product_name, Profile, Count, Deployment)
                                        VALUES
                                            (?,?,?,?,?)
                                        ON DUPLICATE KEY UPDATE
                                            JIRA_key = VALUES(JIRA_key),
                                            Product_name = VALUES(Product_name),
                                            Profile = VALUES(Profile),
                                            Count = VALUES(Count),
                                            Deployment = 'PROD'",
                key, name, profile, count, deployment);

            result = mysqlEP -> update("INSERT INTO Account
                                            (JIRA_key, Customer_name, Customer_type, Classification, Account_owner,
                                            Technical_owner, Domain, Primary_contact, Timezone)
                                        VALUES
                                            (?,?,?,?,?,?,?,?,?)
                                        ON DUPLICATE KEY UPDATE
                                            JIRA_key = VALUES(JIRA_key),
                                            Customer_name = VALUES(Customer_name),
                                            Customer_type = VALUES(Customer_type),
                                            Classification = VALUES(Classification),
                                            Account_owner = VALUES(Account_owner),
                                            Technical_owner = 'Nuwan',
                                            Domain = VALUES(Domain),
                                            Primary_contact = VALUES(Primary_contact),
                                            Timezone = VALUES(Timezone)",
                key, customerName, customerType, classification, account_owner,
                technical_owner, domain, primary_contact, timezone);

            match result {
                int c => {
                    io:println("Inserted count: " + c);
                    // The transaction can be force aborted using the `abort` keyword at any time.
                    if (c == 0) {
                        abort;
                    }
                }
                error err => {
                    // The transaction can be force retried using `retry` keyword at any time.
                    io:println(err);
                    retry;
                }
            }
        }
    } onretry {
        io:println("Retrying transaction");
    }
}

function onCommitFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " committed");
}

function onAbortFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " aborted");
}

function handleError(string message, error e, mysql:Client testDB) {
    io:println(message + e.message);
    testDB.stop();
}
