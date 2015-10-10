/**
 * Converts existing Attachments into ContentVersion records (aka Chatter Files).
 *
 * ----------
 * Background
 * ----------
 * In the Winter 16 release, Salesforce introduces a new related list called Files.
 * This new related list specifically shows only Chatter Files shared to the record.
 * Seeing as this is the future of Salesforce content, you may want to plan migrating
 * your existing Attachments to Chatter Files. That is the function of this class.
 * http://docs.releasenotes.salesforce.com/en-us/winter16/release-notes/rn_chatter_files_related_list.htm#topic-title
 *
 * --------------
 * Pre-Requisites
 * --------------
 * 1. To simplify the conversion code, two custom fields need to be added
 *    to the ContentVersion object to store the original attachment id and its parent id.
 *    a. Go to Setup | Customize | Salesforce Files | Fields
 *    b. Create new field Text(255) named "Original Attachment ID" with API name "Original_Attachment_ID__c"
 *    c. Create new field Text(255) named "Original Attachment Parent ID" with API name "Original_Attachment_Parent_ID__c"
 *
 * -------------------
 * Questions & Answers
 * -------------------
 * Q. Why would I want to do this?
 * A. Because Chatter Files provide you much more capabilities around sharing the file
 *    with other users, groups, and records. It also supports file previews and revisions.
 *    It is the future of managing content in Salesforce.
 *
 * Q. Where can I learn more about ContentVersion object?
 * A. https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_contentversion.htm
 *
 * Q. How do I run this class to convert the attachments?
 * A. In Salesforce, open the Developer Console and run this anonymous apex snippet:
 *        Database.executeBatch( new ConvertAttachmentsToFilesBatchable(), 200 );
 *    If you run into governor limits, you may need to reduce the batch size from 200.
 *
 * -------
 * Credits
 * -------
 * Code adapted from Chirag Mehta's post on stackoverflow.
 * http://stackoverflow.com/questions/11395148/related-content-stored-in-which-object-how-to-create-related-content-recor
 */
public class ConvertAttachmentsToFilesBatchable implements Database.Batchable<SObject> {

    public Database.QueryLocator start( Database.BatchableContext context ) {
        System.debug( 'Starting: ' + context );
        return Database.getQueryLocator( 'SELECT id, name, parentId, body, description FROM Attachment' );
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
                original_attachment_id__c = attachment.id,
                original_attachment_parent_id__c = attachment.parentId
            ));

        }

        insert contentVersions;

        /*
         * Step 2
         * Requery ContentVersions to get generated content document id (so we can link records to the content)
         * and the original attachment parent id (the record we want to share the content with)
         */

        contentVersions = [
            SELECT
                id, contentDocumentId,
                original_attachment_id__c,
                original_attachment_parent_id__c
            FROM
                ContentVersion
            WHERE
                id IN :contentVersions
        ];

        /*
         * Step 3
         * Create ContentDocumentLinks to share the new content
         * with the same parent record as the source attachment
         */

        List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();

        for ( ContentVersion contentVersion : contentVersions ) {

            contentDocumentLinks.add( new ContentDocumentLink(
                linkedEntityId = contentVersion.original_attachment_parent_id__c,
                contentDocumentId = contentVersion.contentDocumentId,
                shareType = 'V'
            ));

        }

        insert contentDocumentLinks;

    }

    public void finish( Database.BatchableContext context ) {
        System.debug( 'Finishing: ' + context );
    }

}