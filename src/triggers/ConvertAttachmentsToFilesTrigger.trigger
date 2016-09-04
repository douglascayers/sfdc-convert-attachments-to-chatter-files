/**
 * Enqueues a job to convert the attachments into files.
 */
trigger ConvertAttachmentsToFilesTrigger on Attachment ( after insert ) {

    Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getInstance();

    if ( settings.convert_in_near_real_time__c ) {

        ConvertAttachmentsToFilesQueueable queueable = new ConvertAttachmentsToFilesQueueable(
            Trigger.newMap.keySet(),
            new ConvertAttachmentsToFilesOptions( settings )
        );

        System.enqueueJob( queueable );

    }

}