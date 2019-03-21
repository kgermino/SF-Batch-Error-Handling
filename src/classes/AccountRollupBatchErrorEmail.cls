public without sharing class AccountRollupBatchErrorEmail implements Database.Batchable<SObject>, Database.Stateful {
    public Integer errorFactor = 0; //1/N = portion of contacts (520 total) that will fail; 0 = no failures
    private List<String> errors = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext jobId) {
        return Database.getQueryLocator([SELECT Id, Number_of_Contacts__c FROM Account]);
    }

    public void execute(Database.BatchableContext jobId, List<SObject> recordList) {
        Map<Id, Account> accountsByIds = new Map<Id, Account>((List<Account>) recordList);
        try {
            List<Contact> contactsForAccounts = [SELECT Id, AccountId FROM Contact WHERE AccountId IN :accountsByIds.keySet()];

            updateNumberOfContactsOnAccounts(accountsByIds, contactsForAccounts);

            update accountsByIds.values();
        } catch (Exception e) {
            String retainedErrorMessage = 'Error on Records With Ids: ' +
                    accountsByIds.keySet() + '\n' +
                    e.getMessage() + '\n' + e.getStackTraceString();

            errors.add(retainedErrorMessage);
        }
    }

    public void finish(Database.BatchableContext jobId) {
        String errorMessageBody = 'Bad Things Below\n\n\n';
        for (String errorString : errors) {
            errorMessageBody += errorString + '\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n';
        }

        Messaging.SingleEmailMessage errorEmail = new Messaging.SingleEmailMessage();
        errorEmail.toAddresses = new List<String>{'germino.kevin@gmail.com'};
        errorEmail.subject = 'Errors Occurred Running AccountRollupBatchErrorEmail';
        errorEmail.plainTextBody = errorMessageBody;

        Messaging.sendEmail(new List<Messaging.Email>{errorEmail});

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
        if (entropy <= 1) {
            throw new accountRollupException('Random Error Thrown');
        }
    }

    public class accountRollupException extends Exception {}
}