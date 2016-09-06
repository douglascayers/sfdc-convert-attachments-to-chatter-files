/**
 * Enqueues a job to convert the attachments into files.
 * Note, some triggers aren't fired for actions performed in Case Feed:
 * https://success.salesforce.com/issues_view?id=a1p300000008YTEAA2
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