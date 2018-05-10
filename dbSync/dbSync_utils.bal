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

function organizeSfData(json resultFromSf) returns map {
    json[] records = check <json[]>resultFromSf.records;
    map<json[]> sfDataMap;

    foreach record in records {
        string jiraKey = record["Support_Accounts__r"]["records"][0]["JIRA_Key__c"].toString();
        io:println(jiraKey);

        json opportunity = {
            "Id": record["Id"],
            "Account": {
                "Id": record["Account"]["Id"],
                "Name": record["Account"]["Name"],
                "Classification": record["Account"]["Account_Classification__c"],
                "Owner": record["Account"]["Owner"]["Name"],
                "Rating": record["Account"]["Rating"]["Name"],
                "TechnicalOwner": record["Account"]["Technical_Owner__c"],
                "Industry": record["Account"]["Industry"],
                "Phone": record["Account"]["Phone"],
                "BillingAddress": record["Account"]["BillingAddress"]
            },
            "SupportAccount": {
                "Id": record["Support_Accounts__r"]["records"][0]["Id"],
                "JiraKey": record["Support_Accounts__r"]["records"][0]["JIRA_Key__c"],
                "StartDate": record["Support_Accounts__r"]["records"][0]["Start_Date__c"],
                "EndDate": record["Support_Accounts__r"]["records"][0]["End_Date__c"]
            },
            "OpportunityLineItems": []
        };

        foreach item in record["OpportunityLineItems"]["records"] {
            json lineItem = {
                "Id": item["Id"],
                "Quantity": item["Quantity"],
                "Environment": item["Environment__c"],
                "Product": item["PricebookEntry"]["Name"]
            };

            opportunity["OpportunityLineItems"][lengthof opportunity["OpportunityLineItems"]] = lineItem;
        }

        if (!sfDataMap.hasKey(jiraKey)) {
            io:println("Adding key: " + jiraKey);
            sfDataMap[jiraKey] = [record];
        } else {
            io:println("Has jira key: " + jiraKey);
            int index = (lengthof sfDataMap[jiraKey]);

            sfDataMap[jiraKey][index] = record;
        }
    }
    return sfDataMap;
}