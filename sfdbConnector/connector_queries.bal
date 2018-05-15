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

@final string QUERY_TEMPLATE_GET_CUSTOMER_DETAILS_BY_JIRA_KEYS = "

    SELECT
        Account.account_id,
        Account.customer_name,
        Account.customer_type,
        Account.classification,
        Account.account_owner,
        Account.technical_owner,
        Account.domain,
        Account.primary_contact,
        Account.city,
        Account.country,
        Account.geocode_accuracy,
        Account.latitude,
        Account.longitude,
        Account.postal_code,
        Account.state,
        Account.street,

        Opportunity.opportunity_id,
        Opportunity.account_id,

        OpportunityProducts.opportunity_id,
        OpportunityProducts.opportunity_product_id,
        OpportunityProducts.name,
        OpportunityProducts.profile,
        OpportunityProducts.count,
        OpportunityProducts.deployment,

        SupportAccount.opportunity_id,
        SupportAccount.support_account_id,
        SupportAccount.jira_key

    FROM
        SupportAccount

    INNER JOIN Opportunity ON SupportAccount.opportunity_id = Opportunity.opportunity_id
    INNER JOIN Account ON Account.account_id = Opportunity.account_id
    INNER JOIN OpportunityProducts ON OpportunityProducts.opportunity_id = Opportunity.opportunity_id

    WHERE
        jira_key IN <JIRA_KEY_LIST>";


@final string QUERY_TEMPLATE_GET_PROJECT_DETAILS_BY_JIRA_KEYS = "

    SELECT
        JiraProject.jira_key,
        JiraProject.project_name,
        JiraProject.category

    FROM
        JiraProject

    WHERE
        jira_key IN <JIRA_KEY_LIST>";


@final string QUERY_TEMPLATE_GET_JIRA_KEYS_BY_PROJECT = "

    SELECT
        JiraProject.jira_key,
        JiraProject.project_name

    FROM
        JiraProject

    WHERE
        (jira_key LIKE '%<PATTERN>%') OR (project_name LIKE '%<PATTERN>%')";

