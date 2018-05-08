function organizeSfData(json response) returns json{
    json[] records = check <json[]> response.records;
    map data;
    foreach record in records {
        //string jiraKey = record.jira_key.toString();
        //json[] opportunityJsonObj = record.Opportunity;
        //data = {jiraKey:[opportunityJsonObj]};
    }
    return {};
}