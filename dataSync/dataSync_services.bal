import ballerina/mysql;
import ballerina/io;
import ballerina/http;
import ballerina/config;
import ballerina/log;
import sfdc37;
import dataCollector as dc;

endpoint mysql:Client mysqlEP {
    host:config:getAsString("HOST"),
    port:config:getAsInt("PORT"),
    name:config:getAsString("NAME"),
    username:config:getAsString("USERNAME"),
    password:config:getAsString("PASSWORD"),
    poolOptions:{maximumPoolSize:config:getAsInt("POOL_SIZE")}
};

endpoint http:Client httpClientEP{
    url:config:getAsString("HTTP_ENDPOINT_URL")
    //,timeoutMillis:300000
};


endpoint http:Listener listener {
    port:config:getAsInt("DATA_SYNC_SERVICE_HTTP_PORT")
};

@http:ServiceConfig {
    endpoints:[listener],
    basePath:"/sync/salesforce"
}
service<http:Service> dataSyncService bind listener {

    @http:ResourceConfig {
        methods:["GET"],
        path:"/start"
    }
    startSyncData(endpoint caller, http:Request request) {
        log:printInfo("Sync service triggered!");
        http:Response response = new;
        _ = caller -> respond(response);

        log:printDebug("Getting active JIRA keys...");
        string[] keysFromJira = check getJiraKeysFromJira();
        string[] keysFromSfDb = check getJiraKeysFromDB();

        //Get JIRA keys toBeDeleted and toBeUpserted
        log:printDebug("Categorizing keys to be deleted and upserted!");
        map categorizedJiraKeys = dc:categorizeJiraKeys(keysFromJira, keysFromSfDb);

        string[] jiraKeysToBeDeleted = check <string[]>categorizedJiraKeys.toBeDeleted;
        json[] jiraKeysToBeUpserted = check <json[]>categorizedJiraKeys.toBeUpserted;

        log:printInfo("Starting sync with Salesforce DB...");

        log:printInfo("Deleting records from Salesforce DB...");
        if(deleteJiraKeys(jiraKeysToBeDeleted)){
            log:printInfo("Successfully deleted JIRA keys");
        }

        //===============================================================================================//
        log:printDebug("Getting data from Salesforce API...");

        http:Request httpRequest = new;
        httpRequest.setJsonPayload(jiraKeysToBeUpserted);
        var out = httpClientEP->post("/collector/salesforce/", request = httpRequest);
        match out {
            http:Response resp => {
                json organizedSfData = organizeSfData(check resp.getJsonPayload());
                io:println(resp.getJsonPayload());
            }
            error err => {
                io:println(err.message);
            }
        }

        //TODO: get data in to variables from organizedSfData

        //===============================================================================================//
        //Upsertion transaction

        log:printDebug("Starting transaction: deleting records from Salesforce DB...");
            foreach upsertKey in jiraKeysToBeUpserted {
                transaction with retries = 4, oncommit = onCommitFunction, onabort = onAbortFunction {
                // START TRANSACTION
                var result = mysqlEP -> update(QUERY_TO_INSERT_VALUES_TO_OPPORTUNITY_PRODUCTS,
                    key, name, profile, count, deployment);

                result = mysqlEP -> update(QUERY_TO_INSERT_VALUES_TO_ACCOUNT,
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
                } onretry {
                    io:println("Retrying transaction");
                }
        }
    }
}

//Transaction util functions
function onCommitFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " committed");
}

function onAbortFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " aborted");
}

function handleError(string message, error e, mysql:Client testDB) {
    io:println(message + e.message);
}

function getJiraKeysFromJira() returns string[]|error{
    //Get JIRA keys from JIRA API
    http:Request httpRequest = new;
    var out = httpClientEP -> get("/collector/jira/keys", request = httpRequest);
    match out {
        http:Response resp => {
            io:println(resp.getJsonPayload()!toString());
            // TODO: use try catch here
            return check <string[]>check resp.getJsonPayload();
        }
        error err => {
            log:printError("Failed to fetch JIRA keys from JIRA API. Error: " + err.message);
            return err;
        }
    }
}

function getJiraKeysFromDB() returns string[]|error{
    //Get JIRA keys from Salesforce RecordStatus DB table
    var selectResults = mysqlEP -> select(QUERY_TO_GET_JIRA_KEYS_FROM_RECORD_STATUS_TABLE, ());
    match selectResults {
        table tableReturned => {
            io:println(tableReturned);
            // todo: Get JIRA keys from table
            string[] results;
            return results;

        }
        error err => {
            log:printError("<SELECT jira_key FROM 'RecordStatus'> failed! Error: " + err.message);
            return err;
        }
    }
}

function deleteJiraKeys(string[] jiraKeysToBeDeleted) returns boolean {
    string[] oppIds;
    string[] oppIdsToBeDeleted;
    string[] accountIds;
    string[] accountIdsToBeDeleted;

    log:printDebug("Starting transaction: deleting records from Salesforce DB...");
    transaction with retries = 4, oncommit = onCommitFunction, onabort = onAbortFunction {

    // Get JIRA keys from SF DB, RecordStatus table
    var selectResultsJiraKeys = mysqlEP -> select(QUERY_TO_GET_JIRA_KEYS_FROM_RECORD_STATUS_TABLE, ());
    match selectResultsJiraKeys {
        table tableReturned => {
            io:println(tableReturned);
        }
        error err => {
            log:printError("SELECT query failed! Error: " + err.message);
        }
    }

    // Get Opportunity Ids by jira keys
    var selectResultsOppIds = mysqlEP -> select(dc:buildQueryFromTemplate(
    QUERY_TEMPLATE_GET_OPPORTUNITY_IDS_BY_JIRA_KEYS, jiraKeysToBeDeleted), ());
    match selectResultsOppIds {
        table tableReturned => {
            io:println(tableReturned);
            string[] oppIds;
        }
        error err => {
            log:printError("SELECT query failed! Error: " + err.message);
        }
    }

    // Out of those Opportunity Ids, find which are not used in other Support Accounts to be deleted
    var selectResultsOppIdsToDelete = mysqlEP -> select(dc:buildQueryFromTemplate(
    QUERY_TEMPLATE_GET_OPPORTUNITY_IDS_TO_BE_DELETED, oppIds), ());
    match selectResultsOppIdsToDelete {
        table tableReturned => {
            io:println(tableReturned);
            string[] oppIdsToBeDeleted;
        }
        error err => {
            log:printError("SELECT query failed! Error: " + err.message);
        }
    }

    // Get Account Ids by Opportunity Ids
    var selectResultsAccIds = mysqlEP -> select(dc:buildQueryFromTemplate(
    QUERY_TEMPLATE_GET_ACCOUNT_IDS_BY_OPPORTUNITY_IDS, oppIdsToBeDeleted), ());
    match selectResultsAccIds {
        table tableReturned => {
            io:println(tableReturned);
            string[] accountIds;
        }
        error err => {
            log:printError("SELECT query failed! Error: " + err.message);
        }
    }

    // Get Account Ids to be deleted
    var selectResultsAccIdsToDelete = mysqlEP -> select(dc:buildQueryFromTemplate(
    QUERY_TEMPLATE_GET_ACCOUNT_IDS_TO_BE_DELETED, accountIds), ());
    match selectResultsAccIdsToDelete {
        table tableReturned => {
            io:println(tableReturned);
            string[] accountIdsToBeDeleted;
        }
        error err => {
            log:printError("SELECT query failed! Error: " + err.message);
        }
    }

    var result = mysqlEP -> update(dc:buildQueryFromTemplate
    (QUERY_TEMPLATE_DELETE_FROM_SUPPORT_ACCOUNT_BY_JIRA_KEYS, jiraKeysToBeDeleted));

    result = mysqlEP -> update(dc:buildQueryFromTemplate
    (QUERY_TEMPLATE_DELETE_FROM_ACCOUNT_BY_ACCOUNT_IDS, accountIdsToBeDeleted));

    result = mysqlEP -> update(dc:buildQueryFromTemplate
    (QUERY_TEMPLATE_DELETE_FROM_OPPORTUNITY_BY_OPPORTUNITY_IDS, oppIdsToBeDeleted));

    // Can do this with "ON DELETE CASCADE"
    result = mysqlEP -> update(dc:buildQueryFromTemplate
    (QUERY_TEMPLATE_DELETE_FROM_OPPORTUNITY_PRODUCT_BY_IDS, oppIdsToBeDeleted));

    //TODO: Update BatchStatus table deletion_completed_time

    match result {
        int c => {
            log:printDebug("Deletion transaction completed successfully!!");

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
    } onretry {
        io:println("Retrying transaction");
    }
    return true;
}