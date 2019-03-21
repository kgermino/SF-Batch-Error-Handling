public without sharing class BatchApexErrorEventHandler {
    public static void handleErrors(List<BatchApexErrorEvent> errorEvents) {
        Map<String, Batch_Error__c> errorsByReplayId = saveEventsToDatabase(errorEvents);
        List<Messaging.SingleEmailMessage> alertEmails = new List<Messaging.SingleEmailMessage>();

        for (BatchApexErrorEvent errorEvent : errorEvents) {
            List<String> failedRecordIds = errorEvent.JobScope.split(',');

            Integer newBatchSize = getNewBatchSize(failedRecordIds);
            Set<Id> recordIdsToRetry = getRecordIdsToRetry(failedRecordIds);

            if (newBatchSize != 0) {
                retryFailedBatchJob(errorEvent, recordIdsToRetry, newBatchSize);
            } else {
                Messaging.SingleEmailMessage errorEmail = new Messaging.SingleEmailMessage();
                errorEmail.setOrgWideEmailAddressId('0D21U000000bnZH');
                errorEmail.toAddresses = new List<String>{'germino.kevin@gmail.com'};
                errorEmail.subject = 'Errors Occurred Running Apex Batch Class';
                errorEmail.plainTextBody = 'Full details available at :' + Url.getSalesforceBaseUrl() + '/' + errorsByReplayId.get(errorEvent.ReplayId);
                alertEmails.add(errorEmail);
            }
        }

        if (alertEmails.size() > 0) {
            Messaging.sendEmail(alertEmails);
        }
    }

    private static Map<String, Batch_Error__c> saveEventsToDatabase(List<BatchApexErrorEvent> errorEvents) {
        Map<String, Batch_Error__c> batchErrors = new Map<String, Batch_Error__c>();

        for (BatchApexErrorEvent batchErrorEvent : errorEvents) {
            Batch_Error__c errorRecord = new Batch_Error__c();
            errorRecord.AsynApexJobId__c = batchErrorEvent.AsyncApexJobId;
            errorRecord.Message_Field_Truncated__c = batchErrorEvent.DoesExceedJobScopeMaxLength;
            errorRecord.ExceptionType__c = batchErrorEvent.ExceptionType;
            errorRecord.JobScope__c = batchErrorEvent.JobScope;
            errorRecord.Message__c = batchErrorEvent.Message;
            errorRecord.ReplayId__c = batchErrorEvent.ReplayId;
            errorRecord.RequestId__c = batchErrorEvent.RequestId;
            errorRecord.StackTrace__c = batchErrorEvent.StackTrace;

            batchErrors.put(errorRecord.ReplayId__c, errorRecord);
        }

        insert batchErrors.values();
        return batchErrors;
    }

    private static Set<Id> getRecordIdsToRetry(List<String> failedRecordIds) {
        Set<Id> recordIdsToRetry = new Set<Id>();
        for (String recordId : failedRecordIds) {
            recordIdsToRetry.add((Id) recordId);
        }
        return recordIdsToRetry;
    }

    private static Integer getNewBatchSize(List<String> failedRecordIds) {
        if (failedRecordIds.size() == 1) {
            return 0;
        } else if (failedRecordIds.size() <= 5) {
            return 1;
        } else {
            return failedRecordIds.size() / 5;
        }
    }

    private static void retryFailedBatchJob(BatchApexErrorEvent errorEvent, Set<Id> recordIdsToRetry, Integer newBatchSize) {
        AsyncApexJob job = [SELECT Id, ApexClass.Name FROM AsyncApexJob WHERE Id = :errorEvent.AsyncApexJobId];
        Type apexJobClassType = Type.forName(job.ApexClass.Name);
        Object apexJob = apexJobClassType.newInstance();
        if (apexJob instanceof BatchErrorHandler) {
            BatchErrorHandler handler = (BatchErrorHandler) apexJob;
            handler.retryErrors(recordIdsToRetry, newBatchSize);
        }
    }
}