# SF-Batch-Error-Handling

###Add Demo Fields to Account
Create a new field, Number_of_Contacts__c on Account.  This will be populated by the demo batch job.

###Setup Initial Data
Add text(10) External_Id__c field to Account and Contact
Add Account_External_Id__c field to Contact

Import both objects

Run the following anonymous apex to link contacts to accounts.
```
List<Account> accounts = [SELECT Id, External_Id__c FROM Account];
Map<String, Account> accountsByExternalId = new Map<String, Account>();
for (Account acc : accounts) {
    accountsByExternalId.put(acc.External_Id__c, acc);
}

List<Contact> contacts = [SELECT Id, Account_External_Id__c FROM Contact];
for (Contact con : contacts) { 
    Id accountId = accountsByExternalId.get(con.Account_External_Id__c).Id;
    con.AccountId = accountId;
}

update contacts;
```
Can validate with this query

`SELECT Id, FirstName, LastName, Account.Name FROM Contact`