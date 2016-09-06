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
     *  - OwnerId (of an active user)
     *  - Name
     *  - Description
     *  - Body
     *  - IsPrivate
     */
    public List<ConversionResult> convert( List<Attachment> attachments ) {

        System.debug( '[ConvertAttachmentsToFilesService.convert] Options: ' + this.options );

        List<ConversionRequest> conversionRequests = buildConversionRequests( attachments );

        // attachmentId ==> conversion result
        // as a map for easy retrieval throughout the various steps doing the conversion
        // and creation of content document links to share new file with parent record.
        // we update the message field on the result occasionally in subsequent steps
        Map<ID, ConversionResult> conversionResultsMap = new Map<ID, ConversionResult>();

        /*
         * Step 0
         * Filter attachments by whether their parent object supports feed tracking or not.
         * If parent doesn't support feed tracking then we can't create ContentDocumentLink
         * records sharing the file with the parent record.
         */

        List<ConversionRequest> requestsToConvert = new List<ConversionRequest>();

        for ( ConversionRequest request : conversionRequests ) {

            Attachment attachment = request.attachment;
            SObjectType parentSObjectType = request.shareToEntityId.getSObjectType();
            DescribeSObjectResult parentDescribe = parentSObjectType.getDescribe();

            if ( parentDescribe.isFeedEnabled() || this.options.convertIfFeedTrackingDisabledOnParentObject ) {

                requestsToConvert.add( request );

            } else {

                ConversionResult result = new ConversionResult();
                result.success = false;
                result.attachmentId = attachment.id;
                result.message  = 'Chatter Feed Tracking is not enabled for parent object type [' + parentSObjectType + ']. ';
                result.message += 'Either enable feed tracking or enable the [Convert If Feed Tracking Disabled?] custom setting.';

                System.debug( LoggingLevel.WARN, '[ConvertAttachmentsToFilesService.convert] conversion result = ' + result );

                conversionResultsMap.put( attachment.id, result );

            }

        }

        /*
         * Step 1
         * Convert Attachments to ContentVersions
         */

        List<ContentVersion> contentVersions = new List<ContentVersion>();

        for ( ConversionRequest request : requestsToConvert ) {

            Attachment attachment = request.attachment;

            // note, we cannot set the ownerId on create but
            // we are able to update the ownerId, so we do that in later step
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
        Map<ID, ConversionRequest> contentVersionToAttachmentsMap = new Map<ID, ConversionRequest>();
        for ( Integer i = 0; i < contentVersions.size(); i++ ) {

            contentVersionToAttachmentsMap.put(
                contentVersions[i].id,
                requestsToConvert[i]
            );

            ConversionResult result = new ConversionResult();
            result.success = true;
            result.contentVersionId = contentVersions[i].id;
            result.attachmentId = requestsToConvert[i].attachment.id;

            System.debug( '[ConvertAttachmentsToFilesService.convert] conversion result = ' + result );

            conversionResultsMap.put( requestsToConvert[i].attachment.id, result );

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

            ConversionRequest request = contentVersionToAttachmentsMap.get( contentVersion.id );
            Attachment attachment = request.attachment;

            System.debug( '[ConvertAttachmentsToFilesService.convert] contentVersion = ' + contentVersion );
            System.debug( '[ConvertAttachmentsToFilesService.convert] oldAttachment = ' + attachment );

            // retain original ownership
            // we couldn't set ownerId on create but we can on update
            contentVersion.ownerId = attachment.ownerId;

            SObjectType parentSObjectType = request.shareToEntityId.getSObjectType();
            DescribeSObjectResult parentDescribe = parentSObjectType.getDescribe();

            if ( parentDescribe.isFeedEnabled() ) {

                // should converted file be shared with parent?
                if ( !attachment.isPrivate || ( attachment.isPrivate && this.options.sharePrivateAttachmentsWithParentRecord ) ) {

                    // share the new file with the same parent entity of the old attachment
                    // any user with visibility to this record has visibility to this file
                    contentDocumentLinks.add( new ContentDocumentLink(
                        linkedEntityId = request.shareToEntityId,
                        contentDocumentId = contentVersion.contentDocumentId,
                        shareType = 'V'
                    ));

                } else {

                    String message  = 'Not creating ContentDocumentLink to share ContentDocument (' + contentVersion.contentDocumentId + ') with Parent Record (' + request.shareToEntityId + ') because attachment record (' + attachment.id + ') is private. ';
                           message += 'Either make attachment record not private or enable the [Share Private Attachments?] custom setting.';

                    conversionResultsMap.get( attachment.id ).message += ' ' + message;

                    System.debug( LoggingLevel.WARN, message );

                }

            } else {

                String message = 'Not creating ContentDocumentLink to share ContentDocument (' + contentVersion.contentDocumentId + ') with Parent Record (' + request.shareToEntityId + ') because [' + parentSObjectType + '] does not have Chatter Feed Tracking enabled.';

                conversionResultsMap.get( attachment.id ).message += ' ' + message;

                System.debug( LoggingLevel.WARN, message );

            }

        }

        // apply updates to content versions, specifically setting owner id to original attachment owner id
        if ( contentVersions.size() > 0 ) {

            System.debug( '[ConvertAttachmentsToFilesService.convert] updating content versions: ' + contentVersions );
            update contentVersions;

        }

        // create share links between new file and original attachment parent entity
        if ( contentDocumentLinks.size() > 0 ) {

            System.debug( '[ConvertAttachmentsToFilesService.convert] inserting content document links: ' + contentDocumentLinks );
            insert contentDocumentLinks;

        }

        // lastly, delete the original attachments that were successfully converted into files
        if ( this.options.deleteAttachmentsUponConversion ) {

            List<Attachment> attachmentsToDelete = new List<Attachment>();

            for ( ContentVersion contentVersion : contentVersions ) {
                attachmentsToDelete.add( new Attachment( id = contentVersion.original_record_id__c ) );
            }

            System.debug( '[ConvertAttachmentsToFilesService.convert] deleting original attachments: ' + attachmentsToDelete );

            delete attachmentsToDelete;

        }

        return conversionResultsMap.values();
    }

    /**
     * Inspects each attachment and applies various logic to determine the entity that the newly converted file
     * should be shared with. For example, majority of attachments converted to files will be shared with their original parent.
     * But some records may need to be shared with a different entity, such as with Email-2-Case scenario.
     * The attachment of an inbound EmailMessage can't be shared as a file to EmailMessage object because it doesn't support Feed Tracking,
     * but we can share the file with the parent Case. So, the conversion request generated for attachments of inbound EmailMessages
     * might say to share the new file with the parent case instead.
     */
    private List<ConversionRequest> buildConversionRequests( List<Attachment> attachments ) {

        List<ConversionRequest> requests = new List<ConversionRequest>();

        // for any attachments related to EmailMessage then
        // we put the email message id in the set to query for more details
        // and we put the attachment in the list to know the specific records
        // to analyze in subsequent step with the queried email messages
        Set<ID> emailMessageIds = new Set<ID>();
        List<Attachment> emailMessageAttachments = new List<Attachment>();

        for ( Attachment attachment : attachments ) {

            SObjectType parentSObjectType = attachment.parentId.getSObjectType();
            Boolean isParentEmailMessage = ( EmailMessage.sObjectType == parentSObjectType );
            Boolean doConvertInboundEmails = this.options.convertInboundEmailMessageAttachmentsToFilesOnCases;

            if ( isParentEmailMessage && doConvertInboundEmails ) {

                emailMessageIds.add( attachment.parentId );
                emailMessageAttachments.add( attachment );

            } else {

                ConversionRequest request = new ConversionRequest();
                request.attachment = attachment;
                request.shareToEntityId = attachment.parentId;

                requests.add( request );

            }

        }

        if ( emailMessageIds.size() > 0 ) {

            // note, the parent id of email message is a case
            // if Enhanced Email is enabled then parent id may be blank if not related to a case
            // https://releasenotes.docs.salesforce.com/en-us/summer16/release-notes/rn_sales_productivity_email_enhanced_setup.htm
            // https://releasenotes.docs.salesforce.com/en-us/summer16/release-notes/emailadmin_enhanced_email_considerations.htm
            Map<ID, EmailMessage> emailMessagesMap = new Map<ID, EmailMessage>([
                SELECT
                    id, parentId
                FROM
                    EmailMessage
                WHERE
                    id IN :emailMessageIds
                    AND
                    incoming = true
                    AND
                    hasAttachment = true
                    AND
                    parentId != null
            ]);

            for ( Attachment attachment : emailMessageAttachments ) {

                EmailMessage message = emailMessagesMap.get( attachment.parentId );

                // if the email message was an incoming message related to a case
                // then let's relate the converted file to the case, not email message,
                // otherwise setup standard request to relate converted file to attachment parent.
                // even though it may fail in conversion we have error handling setup further
                // along in the conversion logic, not here
                if ( message != null ) {

                    ConversionRequest request = new ConversionRequest();
                    request.attachment = attachment;
                    request.shareToEntityId = message.parentId;

                    requests.add( request );

                } else {

                    ConversionRequest request = new ConversionRequest();
                    request.attachment = attachment;
                    request.shareToEntityId = attachment.parentId;

                    requests.add( request );

                }

            }

        }

        return requests;
    }

    /**
     * Generally speaking, attachment conversions share the new file with the attachment's parent.
     * However, there may be instances where that is not possible and you want a "next best thing".
     * This is exactly the scenario when wanting to convert attachments of inbound email messages
     * to Cases (e.g. customers using Email-2-Case). The EmailMessage object does not support Feed Tracking
     * so the file can't be shared to it, but we can share the file to the Case. Ergo, Email-2-Case conversions
     * would specify the Case ID as the entity to share with instead of the EmailMessage ID.
     */
    public class ConversionRequest {

        // the record to convert into file; required
        public Attachment attachment { get; set; }

        // the entity to share the file to via ContentDocumentLink record; required
        public ID shareToEntityId { get; set; }

    }

    public class ConversionResult {

        // true if attachment was converted; false otherwise
        public Boolean success { get; set; }

        // if of the attachment being converted, should always be populated
        public ID attachmentId { get; set; }

        // id of the converted file, if successful, null otherwise
        public ID contentVersionId { get; set; }

        // if not successful then the error message
        // even if success is true may include message if could not share file to intended parent entity
        public String message { get; set; }

        public ConversionResult() {
            this.success = false;
            this.message = '';
        }

    }

}