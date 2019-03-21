public without sharing class AccountRollupBatch implements Database.Batchable<SObject>, Database.RaisesPlatformEvents, BatchErrorHandler {
    public Integer errorFactor = 0; //1/N = portion of contacts (520 total) that will fail; 0 = no failures
    private Set<Id> accountIds;

    public AccountRollupBatch() {
        accountIds = null;
    }

    public AccountRollupBatch(Set<Id> accountIds) {
        this.accountIds = accountIds;
    }

    public Database.QueryLocator start(Database.BatchableContext jobId) {
        if (accountIds == null) {
            return Database.getQueryLocator([SELECT Id, Number_of_Contacts__c FROM Account]);
        } else {
            return Database.getQueryLocator([SELECT Id, Number_of_Contacts__c FROM Account WHERE Id IN :accountIds]);
        }
    }

    public void execute(Database.BatchableContext jobId, List<SObject> recordList) {
        Map<Id, Account> accountsByIds = new Map<Id, Account>((List<Account>) recordList);
        List<Contact> contactsForAccounts = [SELECT Id, AccountId FROM Contact WHERE AccountId IN :accountsByIds.keySet()];

        updateNumberOfContactsOnAccounts(accountsByIds, contactsForAccounts);

        update accountsByIds.values();
    }

    public void finish(Database.BatchableContext jobId) {
    }

    private void updateNumberOfContactsOnAccounts(Map<Id, Account> accountsById, List<Contact> contacts) {
        for (Account acct : accountsById.values()) {
            acct.Number_of_Contacts__c = 0;
        }

        for (Contact con : contacts) {
            accountsById.get(con.AccountId).Number_of_Contacts__c++;
            throwRandomError();
        }
    }

    private void throwRandomError() {
        Decimal entropy = Math.random() * errorFactor;
        if (entropy <= 1 && errorFactor != 0) {
            throw new accountRollupException('Random Error Thrown');
        }
    }

    public void retryErrors(Set<Id> recordIds, Integer batchSize) {
        AccountRollupBatch batch = new AccountRollupBatch(recordIds);
        Database.executeBatch(batch, batchSize);
    }

    public class accountRollupException extends Exception {}
}