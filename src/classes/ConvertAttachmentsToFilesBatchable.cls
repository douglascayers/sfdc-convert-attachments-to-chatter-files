/**
 * -------------------------------------------------------------------------
 * Overview
 * -------------------------------------------------------------------------
 * Converts standard Attachments into fancy Chatter Files.
 * If desired, you may choose to have the old attachments deleted upon conversion.
 * By default the original attachment records will not be deleted and continue to take up storage.
 *
 * -------------------------------------------------------------------------
 * Private Attachments:
 * -------------------------------------------------------------------------
 * Classic Attachments have an 'IsPrivate' checkbox field that restricts
 * visibility to the owner and administrators, all while the attachment is related to the parent record.
 * However, the only way to make the new ContentVersion record private is to not have it shared
 * with any other user, group, or record. So... when converting attachments, you may specify an option
 * to either (true) share the converted private attachment with the parent record and thereby any users
 * who have visibility to the parent record now also have visibility to this converted file or
 * (false) still convert the private attachment but it remains private, only accessible by the owner
 * but will not be found contextually on any record in Salesforce.
 *
 * -------------------------------------------------------------------------
 * Inactive Owners:
 * -------------------------------------------------------------------------
 * ContentVersion records cannot be owned by inactive users.
 * Attempting to causes error: "INACTIVE_OWNER_OR_USER".
 * Even with the 'Update Records with Inactive Owners' system permission,
 * Salesforce will not allow you to set the owner id of a ContentVersion record
 * neither on insert or update. You also cannot share the ContentVersion with inactive users,
 * so we cannot even create ContentVersionLinks to those users.
 * If there is no way to associate a converted file with the original inactive owner
 * then the new file would be owned by the current user running the conversion only,
 * that may not be of any use to anyone so this edge case is ignored.
 * If you want notes owned by inactive users converted, please re-assign them
 * to an active user then run the conversion code.
 *
 * -------------------------------------------------------------------------
 * Usage:
 * -------------------------------------------------------------------------
 *
 *      // use default options:
 *      //  - don't delete records upon conversion
 *      //  - don't share private attachments with parent record (keep them private after conversion)
 *      //  - convert all attachments in the system
 *      Database.executeBatch( new ConvertAttachmentsToFilesBatchable(), 200 );
 *
 *      // customize conversion options
 *      ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable();
 *      batchable.deleteAttachmentsUponConversion = true;
 *      batchable.sharePrivateAttachmentsWithParentRecord = true;
 *      Database.executeBatch( batchable, 100 );
 *
 *      // scope conversion to specific parent records
 *      ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable();
 *      batchable.parentIds = new Set<ID>{ '001j0000003ZS24', '001j0000003ZS1z' };
 *      Database.executeBatch( batchable, 100 );
 *
 * https://github.com/DouglasCAyers/sfdc-convert-attachments-to-chatter-files
 */
public class ConvertAttachmentsToFilesBatchable implements Database.Batchable<SObject>, Database.Stateful {

    // Should the Attachments be deleted upon conversion to ContentVersion?
    // Deleting them reduces redundant data storage.
    // Make sure you've backed up your data before enabling this.
    public Boolean deleteAttachmentsUponConversion = false;

    // Classic Attachments have a 'IsPrivate' field that when checked the attachment
    // is only visible to the owner and administrators. To preserve this
    // then the new ContentVersion cannot be shared with the parent record
    // because doing so would grant any user who has at least read access
    // to the record to now have read access to the previously private attachment content.
    // The alternative is to still convert the attachment but don't share it with the
    // parent record; however, now the new Files are not categorized at all
    // so these now technically private new Files have no context beyond their content.
    // As with the delete option, I err on the side of caution and do nothing unless you enable this option.
    public Boolean sharePrivateAttachmentsWithParentRecord = false;

    // Scope the conversion to just attachments related to specific records
    // if null then ALL attachments in the system will be converted
    // if empty then NO attachments will be converted
    // if non-empty then only attachments related to those records will be converted
    public Set<ID> parentIds = null;

    // ----------------------------------------------------------

    public Database.QueryLocator start( Database.BatchableContext context ) {

        System.debug( 'Starting: ' + context );
        System.debug( 'deleteAttachmentsUponConversion = ' + this.deleteAttachmentsUponConversion );
        System.debug( 'sharePrivateAttachmentsWithParentRecord = ' + this.sharePrivateAttachmentsWithParentRecord );
        System.debug( 'parentIds = ' + this.parentIds );

        if ( this.parentIds == null ) {

            return Database.getQueryLocator([
                SELECT
                    id, ownerId, owner.isActive, parentId, name, body, description, isPrivate
                FROM
                    Attachment
                WHERE
                    owner.isActive = true
                ORDER BY
                    parentId
            ]);

        } else {

            return Database.getQueryLocator([
                SELECT
                    id, ownerId, owner.isActive, parentId, name, body, description, isPrivate
                FROM
                    Attachment
                WHERE
                    parentId IN :this.parentIds
                    AND
                    owner.isActive = true
                ORDER BY
                    parentId
            ]);

        }
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
                original_record_parent_id__c = attachment.parentId,
                original_record_owner_id__c = attachment.ownerId
            ));

        }

        insert contentVersions;

        System.debug( 'contentVersions = ' + contentVersions );

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
                id, ownerId, contentDocumentId
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

            // retain original ownership
            contentVersion.ownerId = attachment.ownerId;

            // should converted file be shared with parent?
            if ( !attachment.isPrivate || ( attachment.isPrivate && this.sharePrivateAttachmentsWithParentRecord ) ) {

                // share the new file with the same parent entity of the old attachment
                // any user with visibility to this record has visibility to this file
                contentDocumentLinks.add( new ContentDocumentLink(
                    linkedEntityId = attachment.parentId,
                    contentDocumentId = contentVersion.contentDocumentId,
                    shareType = 'V'
                ));

            }

        }

        System.debug( 'updating content versions: ' + contentVersions );
        if ( contentVersions.size() > 0 ) {
            update contentVersions;
        }

        System.debug( 'inserting content document links: ' + contentDocumentLinks );
        if ( contentDocumentLinks.size() > 0 ) {
            insert contentDocumentLinks;
        }

        if ( this.deleteAttachmentsUponConversion ) {
            System.debug( 'deleting original attachments: ' + attachments );
            delete attachments;
        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( 'Finishing: ' + context );

    }

}
