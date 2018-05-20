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

function updateSyncRequestedStatus(string uuid) returns boolean {
    log:printDebug("Updating BtachStatus state in to: " + BATCH_STATUS_SYNC_REQUESTED);
    transaction with retries = 3, oncommit = onCommit, onabort = onAbort {
        match getBatchStatusWithLock() {
            BatchStatus bs => {
                boolean result = setBatchStatus(uuid, BATCH_STATUS_SYNC_REQUESTED);
            }
            () => {
                boolean result = addBatchStatus(uuid, BATCH_STATUS_SYNC_REQUESTED);
            }
            error => {
                retry;
            }
        }
    } onretry {
        log:printWarn("Retrying transaction to update batch status to: " + BATCH_STATUS_SYNC_REQUESTED);
    }

    match getBatchStatus() {
        BatchStatus bs => return bs.uuid == uuid && bs.state == BATCH_STATUS_SYNC_REQUESTED;
        ()|error => return false;
    }
}

function updateUuidAndGetBatchStatus(string uuid) returns BatchStatus|() {
    log:printInfo("Inserting UUID: " + uuid + " and getting batch status");
    transaction with retries = 3, oncommit = onCommit, onabort = onAbort {
        match getBatchStatusWithLock() {
            BatchStatus bs => {
                // Set batch uuid
                var updateResult = mysqlEP->update(QUERY_SET_BATCH_UUID, uuid);
                match updateResult {
                    int c => {
                        if (c < 0) {
                            log:printError("Unable to update UUID: " + uuid);
                            abort;
                        } else {
                            log:printInfo("Updated batch UUID: " + uuid);
                        }
                    }
                    error e => {
                        //log:printError("Unable to set UUID: " + uuid, err = e);
                        retry;
                    }
                }
            }
            () => {
                log:printWarn("No existing batch status found");
            }
            error e => {
                retry;
            }
        }
    } onretry {
        log:printWarn("Retrying transaction to update batch UUID: " + uuid);
    }

    match getBatchStatus() {
        BatchStatus bs => {
            return bs.uuid == uuid ? bs : ();
        }
        error|() => return ();
    }
}

function getBatchStatus() returns BatchStatus|()|error {
    BatchStatus|() batchStatus = ();
    var results = mysqlEP->select(QUERY_GET_BATCH_STATUS, BatchStatus);
    // get batch status
    match results {
        table<BatchStatus> entries => {
            while (entries.hasNext()){
                match <BatchStatus>entries.getNext()  {
                    BatchStatus bs => batchStatus = bs;
                    error e => log:printError("Unable to get batch status", err = e);
                }
            }

            return batchStatus;
        }
        error e => {
            log:printError("Unable to get batch status", err = e);
            return e;
        }
    }
}

function getBatchStatusWithLock() returns BatchStatus|()|error {
    BatchStatus|() batchStatus = ();
    var results = mysqlEP->select(QUERY_GET_BATCH_STATUS_WITH_LOCK, BatchStatus);
    // get batch status
    match results {
        table<BatchStatus> entries => {
            while (entries.hasNext()){
                match <BatchStatus>entries.getNext()  {
                    BatchStatus bs => batchStatus = bs;
                    error e => log:printError("Unable to get batch status", err = e);
                }
            }

            return batchStatus;
        }
        error e => {
            log:printError("Unable to get batch status", err = e);
            return e;
        }
    }
}

function getRecordStatusWithLock(string jiraKey) returns RecordStatus|()|error {
    RecordStatus|() recordStatus = ();
    var results = mysqlEP->select(QUERY_GET_RECORD_STATUS_WITH_LOCK, RecordStatus, loadToMemory = false, jiraKey);
    // get record status
    match results {
        table<RecordStatus> entries => {
            //io:println(<json>entries);
            while (entries.hasNext()){
                match <RecordStatus>entries.getNext()  {
                    RecordStatus rs => recordStatus = rs;
                    error e => log:printError("Unable to get record status", err = e);
                }
            }

            return recordStatus;
        }
        error e => {
            log:printError("Unable to get record status", err = e);
            return e;
        }
    }
}

// Should be called within a transaction and having the row lock
function setBatchStatus(string uuid, string status) returns boolean {
    var updateResult = mysqlEP->update(QUERY_SET_BATCH_STATUS, uuid, status);
    match updateResult {
        int c => {
            if (c < 0) {
                log:printError("Unable to update BatctStatus in to: " + status);
                return false;
            } else {
                log:printInfo("Successful! Updated BatctStatus in to: " + status);
                return true;
            }
        }
        error e => {
            log:printError("Unable to update BatctStatus in to 'SYNC_REQUEST'", err = e);
            return false;
        }
    }
}

// Should be called within a transaction and having the row lock
function addBatchStatus(string uuid, string status) returns boolean {
    var result = mysqlEP->update(QUERY_INSERT_BATCH_STATUS, uuid, status);
    match result {
        int c => {
            if (c < 0) {
                log:printError("Unable to insert BatctStatus:" + status);
                return false;
            } else {
                log:printInfo("Successful! Inserted BatctStatus: " + status);
                return true;
            }
        }
        error e => {
            log:printError("Unable to insert BatctStatus: " + status, err = e);
            return false;
        }
    }
}

function checkAndSetInProgressState(string uuid) returns boolean {
    log:printInfo("Inserting UUID: " + uuid + " and setting batch status to `IN_PROGRESS`");
    BatchStatus|() batchStatus = ();
    transaction with retries = 3, oncommit = onCommit, onabort = onAbort {
        match getBatchStatusWithLock() {
            BatchStatus bs => {
                if (bs.uuid != uuid) {
                    log:printWarn(string `My UUID {{uuid}} is different from current batch UUID {{bs.uuid}}. Aborting`);
                    abort;
                }

                if (setBatchStatus(uuid, BATCH_STATUS_IN_PROGRESS)) {
                    log:printInfo("Updated batch status to " + BATCH_STATUS_IN_PROGRESS + " uuid: " + uuid);
                } else {
                    log:printError("Unable to update batch state to " + BATCH_STATUS_IN_PROGRESS + " uuid: " + uuid);
                }
            }
            () => {
                log:printWarn("No existing batch status found");
            }
            error e => {
                //log:printError("Unable to get batch status", err = e);
                retry;
            }
        }
    } onretry {
        log:printWarn("Retrying transaction to update IN_PROGRESS state for batch: " + uuid);
    }

    match getBatchStatus() {
        BatchStatus bs => return bs.uuid == uuid && bs.state == BATCH_STATUS_IN_PROGRESS;
        ()|error => return false;
    }
}


function checkAndSetBatchCompleted(string[] jiraKeys, string uuid) {
    log:printInfo("Checking for batch completion: " + uuid);
    transaction with retries = 3, oncommit = onCommit, onabort = onAbort {
        match getBatchStatusWithLock() {
            BatchStatus bs => {
                if (uuid != bs.uuid) {
                    log:printWarn(string `My UUID {{uuid}} is different from current batch {{bs.uuid}}. Aborting`);
                    return;
                }

                if (lengthof jiraKeys == 0) {
                    log:printDebug("0 records left for completion. Marking as completed");
                    if (bs.state != BATCH_STATUS_COMPLETED && setBatchStatus(uuid, BATCH_STATUS_COMPLETED)) {
                        log:printInfo("Marked batch as : " + BATCH_STATUS_COMPLETED + " uuid: " + uuid);
                    }
                } else {
                    string q = buildQueryFromTemplate(QUERY_INCOMPLETE_RECORD_COUNT, "<JIRA_KEY_LIST>", jiraKeys);
                    var count = mysqlEP->select(q, RecordCount);
                    match count {
                        table tb => {
                            int count = 1;
                            //match <json>tb {
                            //    json j => io:println(j);
                            //    error e => io:println(e);
                            //}

                            while (tb.hasNext()) {
                                match <RecordCount>tb.getNext() {
                                    RecordCount rc => count = rc.c;
                                    error e => log:printError("Unable to read incomplete record count", err = e);
                                }
                            }

                            if (count == 0) {
                                log:printDebug("All records have been completed. Updating batch status");
                                if (setBatchStatus(uuid, BATCH_STATUS_COMPLETED)) {
                                    log:printInfo("Updated BatchStatus to " + BATCH_STATUS_COMPLETED);
                                } else {
                                    log:printError("Unable to update batch state to : " + BATCH_STATUS_COMPLETED);
                                }
                            } else {
                                log:printWarn(count +
                                        " records hasn't been completed. Not marking batch as completed");
                            }
                        }
                        error e => log:printError("Unable to get incompleted records", err = e);
                    }
                }
            }
            () => {
                log:printWarn("No batch status found");
            }
            error e => {
                retry;
            }
        }
    } onretry {
        log:printWarn("Retrying transaction to check batch completion: Batch - " + uuid);
    }
}

function getIncompletedRecordJiraKeys() returns string[] {
    string[] jiraKeys = [];

    var results = mysqlEP->select(QUERY_GET_INCOMPLETE_JIRA_KEYS, ());
    match results {
        table entries => {
            match <json>entries {
                json records => {
                    foreach record in records {
                        jiraKeys[lengthof jiraKeys] = record["jira_key"].toString();
                    }
                }
                error e => log:printError("Unable to fetch incomplete records", err = e);
            }
        }
        error e => {
            log:printError("Unable to fetch incomplete records", err = e);
        }
    }

    return jiraKeys;
}

function clearRecordStatusTable() returns boolean {
    var result = mysqlEP->update(QUERY_CLEAR_RECORD_STATUS_TABLE);
    match result {
        int c => {
            log:printDebug("Cleared record status table");
            return c >= 0;
        }
        error e => {
            log:printError("Unable to clear RecordStatus table", err = e);
            return false;
        }
    }
}

function upsertRecordStatus(string[] jiraKeys) returns boolean {
    log:printDebug("Upserting " + lengthof jiraKeys + " record statuses");
    if (lengthof jiraKeys == 0) {
        log:printWarn("0 records to update status");
        return true;
    }

    string values = "";
    foreach key in jiraKeys {
        values += string `,('{{key}}', NULL)`;
    }

    values = values.replaceFirst(COMMA, EMPTY_STRING);

    transaction with retries = 3, oncommit = onCommit, onabort = onAbort {
        string q = QUERY_BULK_UPSERT_RECORD_STATUS.replace("<ENTRIES>", values);
        log:printDebug("Doing record status bulk update: " + (lengthof jiraKeys) + " jira keys");
        var results = mysqlEP->update(q);
        match results {
            int c => {
                log:printInfo(string `Inserted {{lengthof jiraKeys}} jira keys. Return value {{c}}`);
                if (c < 0) {
                    log:printError("Negative return value for jira key insertion. Aborting");
                    abort;
                }
            }
            error e => {
                //log:printError("Unable to insert record status", err = e);
                retry;
            }
        }
    } onretry {
        log:printWarn("Retrying record status update transaction");
    }

    string q = buildQueryFromTemplate(QUERY_INCOMPLETE_RECORD_COUNT, "<JIRA_KEY_LIST>", jiraKeys);
    var count = mysqlEP->select(q, RecordCount);
    int c = -1;
    match count {
        table tb => {
            while (tb.hasNext()) {
                match <RecordCount>tb.getNext() {
                    RecordCount rc => c = rc.c;
                    error e => log:printError("Unable to read incomplete record status count", err = e);
                }
            }
        }
        error e => log:printError("Unable to check incomplete record status count", err = e);
    }

    return c == lengthof jiraKeys;
}

function buildQueryFromTemplate(string template, string replace, string[] entries) returns string {
    string values = EMPTY_STRING;
    foreach entry in entries {
        values += COMMA + SINGLE_QUOTATION + entry + SINGLE_QUOTATION;
    }
    values = values.replaceFirst(COMMA, EMPTY_STRING);

    return template.replace(replace, values);
}
