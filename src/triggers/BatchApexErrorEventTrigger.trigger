trigger BatchApexErrorEventTrigger on BatchApexErrorEvent (after insert) {
    BatchApexErrorEventHandler.handleErrors(Trigger.new);
}