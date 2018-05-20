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

import ballerina/io;

//this util fuction is used to combine json or string array of jira keys with a defined query template
public function buildQueryFromTemplate(string template, json|string[] jiraKeys) returns string {

    string key_tuple = EMPTY_STRING;
    match jiraKeys {
        json jsonJiraKeys => {
            foreach key in jsonJiraKeys{
                key_tuple += "," + "'" + key.toString() + "'";
            }
        }

        string[] stringJiraKeys => {
            foreach key in stringJiraKeys{
                key_tuple += "," + "'" + key + "'";
            }
        }
    }

    key_tuple = key_tuple.replaceFirst(",", EMPTY_STRING);
    key_tuple = "(" + key_tuple + ")";

    string resultQuery = template.replace("<JIRA_KEY_LIST>", key_tuple);
    return resultQuery;
}

//returns combined response of a set of paginated salesforce responses
function fetchPaginatedDataFromSalesforce(json sfResponse) returns json[]|error|sfdc:SalesforceConnectorError {

    match <json[]>sfResponse[RECORDS]{
        error e => return e;
        json[] records => {
            string nextRecordsUrl = sfResponse[NEXT_RECORDS_URL].toString();
            while (nextRecordsUrl != NULL) { //if the salesforce response is paginated
                int i = lengthof records;
                log:printDebug("nextRecodsUrl is recieved: " + nextRecordsUrl);
                match fetchSalesforceData(nextRecordsUrl) {
                    sfdc:SalesforceConnectorError e => {
                        return e;
                    }
                    json sfResponse => {
                        match <json[]>sfResponse[RECORDS]{
                            json[] nextRecords => {
                                foreach item in nextRecords{
                                    records[i] = item;
                                    i++;
                                }
                                nextRecordsUrl = sfResponse[NEXT_RECORDS_URL].toString();
                            }
                            error e => {
                                return e;
                            }
                        }
                    }
                }
            }
            log:printDebug(<string>(lengthof records) + "records were fetched from salesforce successfully");
            return records;
        }
    }
}

function fetchSalesforceData(string|json jiraKeysOrNextRecordUrl) returns json|sfdc:SalesforceConnectorError {

    match jiraKeysOrNextRecordUrl {

        string nextRecordUrl => {
            var connectorResponse = salesforceClientEP->getNextQueryResult(nextRecordUrl);
            return connectorResponse;
        }

        json jiraKeys => {
            string SOQuery = buildQueryFromTemplate(QUERY_TEMPLATE_GET_SALESFORCE_DATA_BY_JIRA_KEY, jiraKeys);
            var connectorResponse = salesforceClientEP->getQueryResult(SOQuery);
            return connectorResponse;
        }
    }
}



//checks whether a given salesforce response data is paginated ( more data to be fetched )
function hasPaginatedData(json sfResponse) returns boolean {
    string nextRecordsUrl = sfResponse[NEXT_RECORDS_URL].toString();
    if (nextRecordsUrl != NULL)  {
        return true;
    } else {
        return false;
    }
}

//Returns true if the input list has the given jira key
function hasJiraKey(string[] list, string key) returns boolean {
    foreach (item in list){
        if (item == key){
            return true;
        }
    }
    return false;
}

function setErrorResponse(http:Response response, error e) {
    json payload = { "success": false, "response": null, "error": check <json>e };
    response.setJsonPayload(payload);
}

function setSuccessResponse(http:Response response, json|json[] data) {
    json payload = { "success": true, "response": data, "error": null };
    response.setJsonPayload(payload);
}
