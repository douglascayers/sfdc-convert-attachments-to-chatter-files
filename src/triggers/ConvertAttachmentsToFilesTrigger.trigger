/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Enqueues a job to convert the attachments into files.
 * Note, some triggers aren't fired for actions performed in Case Feed:
 * https://success.salesforce.com/issues_view?id=a1p300000008YTEAA2
 */
trigger ConvertAttachmentsToFilesTrigger on Attachment ( after insert ) {

    // we use the instance rather than org defaults here to support
    // overrides on a user or profile level
    Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getInstance();

    if ( settings.convert_in_near_real_time__c ) {

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions( settings );

        ConvertAttachmentsToFilesQueueable queueable = new ConvertAttachmentsToFilesQueueable( Trigger.newMap.keySet(), options, Network.getNetworkId() );

        System.enqueueJob( queueable );

    }

}