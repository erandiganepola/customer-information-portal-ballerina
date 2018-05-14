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

import ballerina/http;
import ballerina/io;
import sfdc37 as sfdc;
import jira7 as jira;
import ballerina/log;
import ballerina/config;
import ballerina/mysql;

//mySQL client global endpoint
endpoint mysql:Client mysqlClientEP {
    host: config:getAsString("SFDB_HOST"),
    port: config:getAsInt("SFDB_PORT"),
    name: config:getAsString("SFDB_NAME"),
    username: config:getAsString("SFDB_USERNAME"),
    password: config:getAsString("SFDB_PASSWORD"),
    poolOptions: { maximumPoolSize: config:getAsInt("SFDB_MAXIMUM_POOL_SIZE") },
    dbOptions: { "useSSL": false }
};

//database connector object
public type SalesforceDatabaseConnector object {

    //Returns the detailed representation of the customers related to a given jira key list
    public function getCustomerDetailsByJiraKeys(string[] jiraKeys) returns json[]|error;

    //Returns the detailed representation of the project details related for a given jira key list
    public function getProjectDetailsByJiraKeys(string[] jiraKeys) returns json[]|error;
};

public function SalesforceDatabaseConnector::getCustomerDetailsByJiraKeys(string[] jiraKeys) returns json[]|error {

    if (lengthof jiraKeys == 0){
        return { message: "No jira keys recieved" };
    }
    else {
        Account[] accounts = [];

        string builtQuery = buildQueryFromTemplate(QUERY_TEMPLATE_GET_CUSTOMER_DETAILS_BY_JIRA_KEYS, jiraKeys);

        var response = mysqlClientEP->select(builtQuery, ());
        match response {
            table results => {
                match <json>results{
                    json jsonResults => {
                        match <json[]>jsonResults{
                            json[] resultsArray => return resultsArray;
                            error e => return e;
                        }
                    }
                    error e => return e;
                }
            }
            error e => return e;
        }
    }
}

public function SalesforceDatabaseConnector::getProjectDetailsByJiraKeys(string[] jiraKeys) returns json[]|error {

    ProjectSummary[] projects = [];

    string builtQuery = buildQueryFromTemplate(QUERY_TEMPLATE_GET_PROJECT_DETAILS_BY_JIRA_KEYS, jiraKeys);

    var response = mysqlClientEP->select(builtQuery, ());
    match response {
        table results => {
            match <json>results{
                json jsonResults => {
                    match <json[]>jsonResults{
                        json[] resultsArray => return resultsArray;
                        error e => return e;
                    }
                }
                error e => return e;
            }
        }
        error e => return e;
    }
}