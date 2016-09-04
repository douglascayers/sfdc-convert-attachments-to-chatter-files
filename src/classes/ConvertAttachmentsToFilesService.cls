/**
 * Work horse that does the actual attachment to file conversion.
 */
public class ConvertAttachmentsToFilesService {

    private ConvertAttachmentsToFilesOptions options { get; set; }

    public ConvertAttachmentsToFilesService() {
        this( new ConvertAttachmentsToFilesOptions() );
    }

    public ConvertAttachmentsToFilesService( ConvertAttachmentsToFilesOptions options ) {
        this.options = options;
    }

    /**
     * Each attachment record should have these fields populated:
     *  - Id
     *  - ParentId
     *  - OwnerId
     *  - Name
     *  - Description
     *  - Body
     */
    public List<ConversionResult> convert( List<Attachment> attachments ) {

        System.debug( '[ConvertAttachmentsToFilesService.convert] Options: ' + this.options );

        List<ConversionResult> conversionResults = new List<ConversionResult>();

        /*
         * Step 0
         * Filter attachments by whether their parent object supports feed tracking or not.
         * If parent doesn't support feed tracking then we can't create ContentDocumentLink
         * records sharing the file with the parent record.
         */

        List<Attachment> attachmentsToConvert = new List<Attachment>();

        for ( Attachment attachment : attachments ) {

            SObjectType parentSObjectType = attachment.parentId.getSObjectType();
            DescribeSObjectResult parentDescribe = parentSObjectType.getDescribe();

            if ( parentDescribe.isFeedEnabled() || this.options.convertIfFeedTrackingDisabledOnParentObject ) {

                attachmentsToConvert.add( attachment );

            } else {

                ConversionResult result = new ConversionResult();
                result.success = false;
                result.attachmentId = attachment.id;
                result.message  = 'Chatter Feed Tracking is not enabled for parent object type [' + parentSObjectType + ']. ';
                result.message += 'Either enable feed tracking or enable the [Convert If Feed Tracking Disabled?] custom setting.';

                System.debug( LoggingLevel.WARN, '[ConvertAttachmentsToFilesService.convert] conversion result = ' + result );

                conversionResults.add( result );

            }

        }

        /*
         * Step 1
         * Convert Attachments to ContentVersions
         */

        List<ContentVersion> contentVersions = new List<ContentVersion>();

        for ( Attachment attachment : attachmentsToConvert ) {

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

        System.debug( '[ConvertAttachmentsToFilesService.convert] contentVersions = ' + contentVersions );

        // create a map of content version ids to attachment record
        // this will be used later on when creating the content document links
        // to share the new file with the attachments parent entity and owner.
        // We build this map here using the loop because at this point in the code
        // we are guaranteed that the index of both lists reference the "same" attachment/file
        Map<ID, Attachment> contentVersionToAttachmentsMap = new Map<ID, Attachment>();
        for ( Integer i = 0; i < contentVersions.size(); i++ ) {

            contentVersionToAttachmentsMap.put(
                contentVersions[i].id,
                attachmentsToConvert[i]
            );

            ConversionResult result = new ConversionResult();
            result.success = true;
            result.contentVersionId = contentVersions[i].id;
            result.attachmentId = attachmentsToConvert[i].id;

            System.debug( '[ConvertAttachmentsToFilesService.convert] conversion result = ' + result );

            conversionResults.add( result );

        }

        System.debug( '[ConvertAttachmentsToFilesService.convert] contentVersionToAttachmentsMap = ' + contentVersionToAttachmentsMap );

        /*
         * Step 2
         * Requery ContentVersions to get generated content document id (so we can link records to the content)
         * and the original attachment parent id (the record we want to share the content with)
         */

        contentVersions = [
            SELECT
                id, ownerId, contentDocumentId,
                original_record_id__c, original_record_parent_id__c, original_record_owner_id__c
            FROM
                ContentVersion
            WHERE
                id IN :contentVersions
        ];

        System.debug( '[ConvertAttachmentsToFilesService.convert] contentVersions = ' + contentVersions );

        /*
         * Step 3
         * Create ContentDocumentLinks to share the new content
         * with the same parent record as the source attachment
         */

        List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();

        for ( ContentVersion contentVersion : contentVersions ) {

            Attachment attachment = contentVersionToAttachmentsMap.get( contentVersion.id );

            System.debug( '[ConvertAttachmentsToFilesService.convert] contentVersion = ' + contentVersion );
            System.debug( '[ConvertAttachmentsToFilesService.convert] oldAttachment = ' + attachment );

            // retain original ownership
            contentVersion.ownerId = attachment.ownerId;

            SObjectType parentSObjectType = attachment.parentId.getSObjectType();
            DescribeSObjectResult parentDescribe = parentSObjectType.getDescribe();

            if ( parentDescribe.isFeedEnabled() ) {

                // should converted file be shared with parent?
                if ( !attachment.isPrivate || ( attachment.isPrivate && this.options.sharePrivateAttachmentsWithParentRecord ) ) {

                    // share the new file with the same parent entity of the old attachment
                    // any user with visibility to this record has visibility to this file
                    contentDocumentLinks.add( new ContentDocumentLink(
                        linkedEntityId = attachment.parentId,
                        contentDocumentId = contentVersion.contentDocumentId,
                        shareType = 'V'
                    ));

                } else {

                    System.debug( LoggingLevel.WARN, 'Not creating ContentDocumentLink to share ContentDocument (' + contentVersion.contentDocumentId + ') with Parent Record (' + attachment.parentId + ') because attachment record (' + attachment.id + ') is private. Either make attachment record not private or enable the [Share Private Attachments?] custom setting.' );

                }

            } else {

                System.debug( LoggingLevel.WARN, 'Not creating ContentDocumentLink to share ContentDocument (' + contentVersion.contentDocumentId + ') with Parent Record (' + attachment.parentId + ') because [' + parentSObjectType + '] does not have Chatter Feed Tracking enabled.' );

            }

        }

        if ( contentVersions.size() > 0 ) {
            System.debug( '[ConvertAttachmentsToFilesService.convert] updating content versions: ' + contentVersions );
            update contentVersions;
        }

        if ( contentDocumentLinks.size() > 0 ) {
            System.debug( '[ConvertAttachmentsToFilesService.convert] inserting content document links: ' + contentDocumentLinks );
            insert contentDocumentLinks;
        }

        if ( this.options.deleteAttachmentsUponConversion ) {
            System.debug( '[ConvertAttachmentsToFilesService.convert] deleting original attachments: ' + attachmentsToConvert );
            delete attachmentsToConvert;
        }

        return conversionResults;
    }

    public class ConversionResult {

        // true if attachment was converted; false otherwise
        public Boolean success { get; set; }

        // id of the converted file, if successful, null otherwise
        public ID contentVersionId { get; set; }

        // if of the attachment being converted
        public ID attachmentId { get; set; }

        // if not successful then the error message
        public String message { get; set; }

    }

}