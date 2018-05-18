//
// Copyright (c) 2018, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//

import ballerina/task;
import ballerina/log;
import ballerina/runtime;
import ballerina/http;
import ballerina/config;

endpoint http:Client dbSyncHttpClientEP{
    url: config:getAsString("DB_SYNC_SERVICE_URI"), timeoutMillis:300000
};

task:Appointment? scheduler1;
task:Appointment? scheduler2;

function main(string... args) {

    log:printInfo("Starting Schedulers...");

    //This job runs daily at 12AM (midnight) to trigger the salesforce database sync process
    scheduler1 = new task:Appointment(beginSync, dbSyncFailError, "0 0 * * * ?");
    scheduler1.schedule();

    //this scheduler runs every 15 minutes to check the sync process and resume if the process is crashed or stopped
    //without being completed
    scheduler2 = new task:Appointment(checkStatus, dbSyncFailError, "0 0/15 * * * ?");
    scheduler2.schedule();

    log:printInfo("Schedulers Started Successfully");
    while(true){}
}

function beginSync() returns (error?) {
    log:printDebug("scheduler 1 triggered full Database Sync");
    return ();
}

function checkStatus() returns (error?) {
    log:printDebug("schedular 2 triggered database sync progress checking");
    return ();
}

function dbSyncFailError(error e) {
    log:printError("[ERROR] failed", err = e);
}
