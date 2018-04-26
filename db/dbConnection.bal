import ballerina/mysql;
import ballerina/io;

function main(string... args) {

    endpoint mysql:Client testDBEP {
        host:"localhost",
        port:3306,
        name:"test_cip",
        username:"root",
        password:"root",
        poolOptions:{maximumPoolSize:5}
    };

    // Create the tables required for the transaction.
    var ret = testDBEP -> update("CREATE TABLE IF NOT EXISTS temp_account (ID INT, Name VARCHAR(30))");
    match ret {
        int retInt => io:println("temp_account table create status in DB: " + retInt);
        error err => {
            handleError("temp_account table Creation failed: ", err, testDBEP);
            return;
        }
    }
    ret = testDBEP -> update("CREATE TABLE IF NOT EXISTS temp_product (ID INT, Name FLOAT)");
    match ret {
        int retInt => io:println("temp_product table create status in DB: " + retInt);
        error err => {
            handleError("temp_product table Creation failed: ", err, testDBEP);
            return;
        }
    }
        // Here is the transaction block. Any transacted action within the transaction block may
        // return errors backend DB errors, connection pool errors, etc., You can decide whether
        // to abort or retry based on the error returned. If you do not explicitly abort or retry,
        // transaction will be automatically retried  until the retry count is reached and aborted.
        // The retry count which is given with `retries` is the number of times the transaction
        // is retried before aborting it. By default, a transaction is tried three times before
        // aborting. Only integer literals or constants are allowed for `retry count`.
        transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {
        // This is the first action participant in the transaction.
            var result = testDBEP->update("INSERT INTO temp_account(ID,Name) VALUES (1, 'Anne')");
            // This is the second action participant in the transaction.
            result = testDBEP->update("INSERT INTO temp_product (ID, Name) VALUES (1, 2500)");
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
                    retry;
                }
            }
        // The end curly bracket marks the end of the transaction and the transaction will
        // be committed or rolled back at this point.
        } onretry {
        // The onretry block will be executed whenever the transaction is retried until it
        // reaches the retry count. Transaction could be re-tried if it fails due to an
        // exception or a throw statement, or an explicit retry statement.
            io:println("Retrying transaction");
        }
//================================ Stored Procedure =============================================//
    // A stored procedure can be invoked using the `call` action. The direction is
    // used to specify `IN`/`OUT`/`INOUT` parameters.

    var retrieve = testDBEP->update("CREATE TABLE IF NOT EXISTS cip(ID INT AUTO_INCREMENT,
    Name VARCHAR(30), PRIMARY KEY (ID))");

    match retrieve {
        int retInt => io:println("cip table create status in DB: " + retInt);
        error err => {
            handleError("cip table Creation failed: ", err, testDBEP);
            return;
        }
    }

    // Create a stored procedure using the `update` action.
    ret = testDBEP->update("CREATE PROCEDURE SETDATA (IN Name VARCHAR(30))
                         BEGIN
                         INSERT INTO cip(Name) VALUES (Name);
                         END");
    match ret {
        int status => io:println("Stored proc creation status: " + status);
        error err => {
            handleError("SETDATA procedure creation failed: ", err, testDBEP);
            return;
        }
    }

    var results = testDBEP->call("{CALL SETDATA('Anne')}",());


    // Drop the STUDENT table.
    ret = testDBEP->update("DROP TABLE cip");
    match ret {
        int status => io:println("Table drop status: " + status);
        error err => {
            handleError("Dropping cip table failed: ", err, testDBEP);
            return;
        }
    }

    // Drop the SETDATA procedure.
    ret = testDBEP->update("DROP PROCEDURE SETDATA");
    match ret {
        int status => io:println("Procedure drop status: " + status);
        error err => {
            handleError("Dropping SETDATA procedure failed: ", err, testDBEP);
            return;
        }
    }

    // Finally, close the connection pool.
    testDBEP.stop();

    }

    // This is the function used as the commit handler of the transaction block. Any action which needs
    // to perform once the transaction is committed should go here.
    function onCommitFunction(string transactionId) {
        io:println("Transaction: " + transactionId + " committed");
    }

    // This is the function used as the abort handler of the transaction block. Any action which needs
    // to perform if the transaction is aborted should go here.
    function onAbortFunction(string transactionId) {
        io:println("Transaction: " + transactionId + " aborted");
    }

function handleError(string message, error e, mysql:Client testDB) {
    io:println(message + e.message);
    testDB.stop();
}
