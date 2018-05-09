//
// Copyright (c) 2018, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing,//
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//

@final string QUERY_TEMPLATE_GET_ACCOUNT_DETAILS_BY_JIRA_KEYS = "
    SELECT
        account_id,
        customer_name,
        customer_type,
        classification,
        account_owner,
        technical_owner,
        domain,
        primary_contact,
        timezone
    FROM
        SupportAccount
    WHERE
        jira_key in <JIRA_KEY_LIST>";

