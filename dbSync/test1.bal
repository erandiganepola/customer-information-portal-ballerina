//import ballerina/io;
//import ballerina/jdbc;
//import ballerina/sql;
//
//// Client endpoint for MySQL database. This client endpoint can be used with any jdbc
//// supported database by providing the corresponding jdbc url.
////endpoint jdbc:Client testDB {
////    url: "jdbc:mysql://localhost:3306/testdb",
////    username: "root",
////    password: "root",
////    poolOptions: { maximumPoolSize: 5 }
////};
//
//
//endpoint mysql:Client testDB {
//    host: "localhost",
//    port: 3306,
//    name: "test_cip",
//    username: "root",
//    password: "root",
//    dbOptions: { "useSSL": false },
//    poolOptions: { maximumPoolSize: 5 }
//};
////SFDB_HOST="localhost"
////SFDB_PORT=3306
////SFDB_NAME="test_cip"
////SFDB_USERNAME="root"
////SFDB_PASSWORD="root"
////SFDB_POOL_SIZE=5
//
//// This is the type created to represent data row.
//type Student {
//    int id,
//    int age,
//    string name,
//};
//
//function main(string... args) {
//    // Creates a table using the update action. If the DDL
//    // statement execution is successful, the `update` action returns 0.
//    io:println("The update operation - Creating a table:");
//    var ret = testDB->update("CREATE TABLE student(id INT AUTO_INCREMENT,
//                         age INT, name VARCHAR(255), PRIMARY KEY (id))");
//    handleUpdate(ret, "Create student table");
//
//
//    // A batch of data can be inserted using the `batchUpdate` action. The number
//    // of inserted rows for each insert in the batch is returned as an array.
//    io:println("\nThe batchUpdate operation - Inserting a batch of data");
//    sql:Parameter para1 = { sqlType: sql:TYPE_INTEGER, value: 27 };
//    sql:Parameter para2 = { sqlType: sql:TYPE_VARCHAR, value: "Alex" };
//    sql:Parameter[] parameters1 = [para1, para2];
//
//    //Create the second batch of parameters.
//    sql:Parameter para3 = { sqlType: sql:TYPE_INTEGER, value: 28 };
//    sql:Parameter para4 = { sqlType: sql:TYPE_VARCHAR, value: "Peter" };
//    sql:Parameter[] parameters2 = [para3, para4];
//
//    sql:Parameter[][] array = [parameters1,parameters2];
//
//    //Do the batch update by passing the multiple parameter arrays.
//    var retBatch = testDB->batchUpdate("INSERT INTO student(age, name)
//                    values (?, ?)", array);
//    match retBatch {
//        int[] counts => {
//            io:println("Batch 1 update counts: " + counts[0]);
//            io:println("Batch 2 update counts: " + counts[1]);
//        }
//        error e => io:println("Batch update action failed: " + e.message);
//    }
//
//    //Drop the table and procedures.
//    io:println("\nThe update operation - Drop the tables and procedures");
//    ret = testDB->update("DROP TABLE student");
//    handleUpdate(ret, "Drop table student");
//
//    //ret = testDB->update("DROP PROCEDURE INSERTDATA");
//    //handleUpdate(ret, "Drop stored procedure INSERTDATA");
//    //
//    //ret = testDB->update("DROP PROCEDURE GETCOUNT");
//    //handleUpdate(ret, "Drop stored procedure GETCOUNT");
//
//    // Finally, close the connection pool.
//    testDB.stop();
//}
//
//// Check crieteria for remove.
//function isUnder20(Student s) returns boolean {
//    return s.age < 20;
//}
//
//// Function to handle return of the update operation.
//function handleUpdate(int|error returned, string message) {
//    match returned {
//        int retInt => io:println(message + " status: " + retInt);
//        error e => io:println(message + " failed: " + e.message);
//    }
//}
