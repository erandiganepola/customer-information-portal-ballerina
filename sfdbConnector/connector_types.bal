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

type Account {
    string id;
    string customerName;
    string customerType;
    string classification;
    string accountOwner;
    string technicalOwner;
    string domain;
    string primaryContact;
    string timeZone;
    Opportunity[] opportunities;
};

type Opportunity {
    string id;
    string accountId;
    OpportunityProduct[] opportunityProducts;
    SupportAccount[] supportAccounts;
};

type OpportunityProduct {
    string id;
    string name;
    string profile;
    string count;
    string deployment;
    string supportAccount;
    string supportAccountType;
};

type SupportAccount {
    string id;
    string opportunityId;
    string jiraKey;
    string startDate;
    string endDate;
};

public type ProjectSummary {
    string key;
    string name;
    string category;
};
