public interface BatchErrorHandler {
    void retryErrors(Set<Id> recordIds, Integer batchSize);
}