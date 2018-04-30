import ballerina/mysql;
import ballerina/io;

function main(string... args) {
    map keys = { toBeDeleted: ["AAALIFEPROD", "AAAMAPROD"], toBeUpdated: ["AAALIFEPROD", "AAAMAPROD"] };
    io:println(keys);
    doTransaction(keys);
}

function doTransaction(map jiraKeys){
    endpoint mysql:Client testDBEP {
        host:"localhost",
        port:3306,
        name:"test_cip",
        username:"root",
        password:"root",
        poolOptions:{maximumPoolSize:5}
    };

    string[] stringKeyList = ["AAALIFEPROD", "AAAMAPROD", "AAANGPROD"];
    //string key = "AAALIFEPROD";
    string name = "APIM";
    string profile = "Business";
    string count = "4";
    string deployment = "DEV";

    string customerName = "William";
    string customerType = "Support";
    string classification = "DEV";
    string account_owner = "John";
    string technical_owner = "Isuru";
    string domain = "PROD";
    string primary_contact = "+94112278456";
    string timezone = "No:14AZ, CA, USA";

    int|error result;
    string[] toBeDeleted = check <string[]> jiraKeys["toBeDeleted"];
    string[] toBeUpserted = check <string[]> jiraKeys["toBeUpserted"];

    transaction with retries = 4, oncommit = onCommitFunction, onabort = onAbortFunction {

        foreach key in toBeDeleted{
            result = testDBEP -> update("DELETE FROM Opportunity_Products where JIRA_key = ?", key);
            result = testDBEP -> update("DELETE FROM Account where JIRA_key = ?", key);

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

        foreach key in toBeUpserted {
            result = testDBEP -> update("INSERT INTO Opportunity_Products
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

            result = testDBEP -> update("INSERT INTO Account
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
    testDBEP.stop();
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
