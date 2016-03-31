/**
 * Converts standard Attachments into fancy Chatter Files.
 * If desired, you may choose to have the old attachments deleted upon conversion.
 * By default the original attachment records will not be deleted and continue to take up storage.
 *
 * Usage:
 *      Database.executeBatch( new ConvertAttachmentsToFilesBatchable(), 200 );
 *
 *      Boolean deleteAttachmentsUponConversion = true;
 *      Database.executeBatch( new ConvertAttachmentsToFilesBatchable( deleteAttachmentsUponConversion ), 200 );
 *
 * https://github.com/DouglasCAyers/sfdc-convert-attachments-to-chatter-files
 */
public class ConvertAttachmentsToFilesBatchable implements Database.Batchable<SObject> {

    // should the Attachments be deleted upon conversion to ContentVersion?
    // Deleting them reduces redundant data storage.
    // Make sure you've backed up your data before enabling this.
    private Boolean deleteAttachmentsUponConversion;

    // Constructor
    public ConvertAttachmentsToFilesBatchable() {
        this( false );
    }

    // Constructor
    public ConvertAttachmentsToFilesBatchable( Boolean deleteAttachmentsUponConversion ) {
        this.deleteAttachmentsUponConversion = deleteAttachmentsUponConversion;
    }

    public Database.QueryLocator start( Database.BatchableContext context ) {

        System.debug( 'Starting: ' + context );

        return Database.getQueryLocator([
            SELECT
                id, ownerId, parentId, name, body, description
            FROM
                Attachment
        ]);
    }

    public void execute( Database.BatchableContext context, List<Attachment> attachments ) {

        System.debug( 'Executing: ' + context );

        /*
         * Step 1
         * Convert Attachments to ContentVersions
         */

        List<ContentVersion> contentVersions = new List<ContentVersion>();

        for ( Attachment attachment : attachments ) {

            contentVersions.add( new ContentVersion(
                versionData = attachment.body,
                title = attachment.name,
                description = attachment.description,
                pathOnClient = '/' + attachment.name,
                // custom fields for history tracking and conversion purposes
                original_record_id__c = attachment.id,
                original_record_parent_id__c = attachment.parentId
            ));

        }

        insert contentVersions;

        // create a map of content version ids to attachment record
        // this will be used later on when creating the content document links
        // to share the new file with the attachments parent entity and owner.
        // We build this map here using the loop because at this point in the code
        // we are guaranteed that the index of both lists reference the "same" attachment/file
        Map<ID, Attachment> contentVersionToAttachmentsMap = new Map<ID, Attachment>();
        for ( Integer i = 0; i < contentVersions.size(); i++ ) {
            contentVersionToAttachmentsMap.put(
                contentVersions[i].id,
                attachments[i]
            );
        }

        System.debug( 'contentVersionToAttachmentsMap = ' + contentVersionToAttachmentsMap );

        /*
         * Step 2
         * Requery ContentVersions to get generated content document id (so we can link records to the content)
         * and the original attachment parent id (the record we want to share the content with)
         */

        contentVersions = [
            SELECT
                id, contentDocumentId
            FROM
                ContentVersion
            WHERE
                id IN :contentVersions
        ];

        System.debug( 'contentVersions = ' + contentVersions );

        /*
         * Step 3
         * Create ContentDocumentLinks to share the new content
         * with the same parent record as the source attachment
         */

        List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();

        for ( ContentVersion contentVersion : contentVersions ) {

            Attachment attachment = contentVersionToAttachmentsMap.get( contentVersion.id );

            System.debug( 'contentVersion = ' + contentVersion );
            System.debug( 'oldAttachment = ' + attachment );

            // share the new file with the same parent entity of the old attachment
            contentDocumentLinks.add( new ContentDocumentLink(
                linkedEntityId = attachment.parentId,
                contentDocumentId = contentVersion.contentDocumentId,
                shareType = 'V'
            ));

            // by default, the current user will be the owner of the new file
            // so we need to make sure we aren't trying to redundantly share
            // access to this record with the same user else get error:
            // "INSUFFICIENT_ACCESS_OR_READONLY, Invalid sharing type C"
            if ( UserInfo.getUserId() != attachment.ownerId ) {
                contentDocumentLinks.add( new ContentDocumentLink(
                    linkedEntityId = attachment.ownerId,
                    contentDocumentId = contentVersion.contentDocumentId,
                    shareType = 'C'
                ));
            }

        }

        System.debug( 'inserting content document links: ' + contentDocumentLinks );
        insert contentDocumentLinks;

        if ( this.deleteAttachmentsUponConversion ) {
            System.debug( 'deleting original attachments: ' + attachments );
            delete attachments;
        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( 'Finishing: ' + context );

    }

}