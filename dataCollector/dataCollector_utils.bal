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

    key_tuple = key_tuple.replaceFirst(",", "");
    key_tuple = "(" + key_tuple + ")";

    string resultQuery = template.replace("<JIRA_KEY_LIST>", key_tuple);
    io:println(resultQuery);
    return resultQuery;
}

public function fetchSalesforceData(string|json jiraKeysOrNextRecordUrl) returns json {

    match jiraKeysOrNextRecordUrl {

        string nextRecordUrl => {
            var connectorResponse = salesforceClientEP->getNextQueryResult(nextRecordUrl);
            match connectorResponse {
                json jsonResponse => {
                    return { "success": true, "response": jsonResponse, error: null };
                }
                sfdc:SalesforceConnectorError e => {
                    return { "success": false, "response": null, "error": check <json>e };
                }
            }
        }

        json jiraKeys => {
            string SOQuery = buildQueryFromTemplate(QUERY_TEMPLATE_GET_SALESFORCE_DATA_BY_JIRA_KEY, jiraKeys);
            var connectorResponse = salesforceClientEP->getQueryResult(SOQuery);
            match connectorResponse {
                json jsonResponse => {
                    return { "success": true, "response": jsonResponse, error: null };
                }
                sfdc:SalesforceConnectorError e => return { "success": false, "response": null, "error": check <json>e };
            }
        }
    }
}

public function categorizeJiraKeys(string[] newKeys, string[] currentKeys) returns map {

    string[] toBeUpserted = [];
    string[] toBeDeleted = [];
    int i_upsert = 0;
    int i_delete = 0;

    foreach (key in newKeys){
        toBeUpserted[i_upsert] = key;
        i_upsert += 1;
    }

    foreach (key in currentKeys){
        if (!hasJiraKey(newKeys, key)){ //update
            toBeDeleted[i_delete] = key;
            i_delete += 1;
        }
    }

    map result = { "toBeUpserted": toBeUpserted, "toBeDeleted": toBeDeleted };
    return result;
}

function hasJiraKey(string[] list, string key) returns boolean {
    foreach (item in list){
        if (item == key){
            return true;
        }
    }
    return false;
}
