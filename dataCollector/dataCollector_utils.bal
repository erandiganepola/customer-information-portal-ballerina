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

public function fetchSalesforceData(string|json jiraKeysOrNextRecordUrl) returns json|sfdc:SalesforceConnectorError {

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
