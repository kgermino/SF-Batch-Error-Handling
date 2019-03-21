public without sharing class BatchApexErrorEventHandler {
    public static void handleErrors(List<BatchApexErrorEvent> errorEvents) {
        saveEventsToDatabase(errorEvents);

        for (BatchApexErrorEvent event : errorEvents) {
            AsyncApexJob job = [SELECT Id, ApexClass.Name FROM AsyncApexJob WHERE Id = :event.AsyncApexJobId];
            Type apexJobClassType = Type.forName(job.ApexClass.Name);
            Object apexJob = apexJobClassType.newInstance();

            List<String> failedRecordIds = errorEvents[0].JobScope.split(',');
            Integer newBatchSize = failedRecordIds.size() / 5;
            Set<Id> recordIdsToRetry = new Set<Id>();
            for (String recordId : failedRecordIds) {
                recordIdsToRetry.add((Id) recordId);
            }

            if (apexJob instanceof BatchErrorHandler && newBatchSize > 0) {
                BatchErrorHandler handler = (BatchErrorHandler) apexJob;
                handler.retryErrors(recordIdsToRetry, newBatchSize);
            }
        }
        //TODO: Handle if size = 0
    }

    private static void saveEventsToDatabase(List<BatchApexErrorEvent> errorEvents) {
        List<Batch_Error__c> batchErrors = new List<Batch_Error__c>();

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

            batchErrors.add(errorRecord);
        }

        insert batchErrors;
    }
}