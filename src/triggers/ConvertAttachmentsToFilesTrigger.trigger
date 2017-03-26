/**
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

        // if community user created this attachment then set sharing of the file to 'AllUsers'
        // so both internal and external users can access the converted file
        // https://success.salesforce.com/0D53A000032fahS

        ID networkId = Network.getNetworkId();

        if ( String.isNotBlank( networkId ) ) {
            options.shareType = 'I';
            options.visibility = 'AllUsers';
        }

        ConvertAttachmentsToFilesQueueable queueable = new ConvertAttachmentsToFilesQueueable( Trigger.newMap.keySet(), options, networkId );

        System.enqueueJob( queueable );

    }

}