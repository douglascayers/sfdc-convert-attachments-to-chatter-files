/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Work horse that does the actual attachment to file conversion.
 */
public with sharing class ConvertAttachmentsToFilesService {

    private ConvertAttachmentsToFilesOptions options { get; set; }

    // if context user is a community user then we
    // need to pass on the network id to assign to ContentVersion
    private ID networkId { get; set; }

    public ConvertAttachmentsToFilesService() {
        this( new ConvertAttachmentsToFilesOptions() );
    }

    public ConvertAttachmentsToFilesService( ConvertAttachmentsToFilesOptions options ) {
        this.options = options;
    }

    public ConvertAttachmentsToFilesService( ConvertAttachmentsToFilesOptions options, ID networkId ) {
        this.options = options;
        this.networkId = networkId;
    }

    /**
     * Each attachment record should have these fields populated:
     *  - Id
     *  - ParentId
     *  - OwnerId
     *  - Name
     *  - Description
     *  - Body
     *  - IsPrivate
     *  - CreatedById
     *  - CreatedDate
     *  - LastModifiedById
     *  - LastModifiedDate
     */
    public List<ConversionResult> convert( List<Attachment> attachments ) {

        // determine if communities are enabled and if so then we will need
        // to assign the network id field when inserting the content versions
        // otherwise error "INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY" occurs
        // if community user uploads an attachment and it tries to get converted
        // https://github.com/DouglasCAyers/sfdc-convert-attachments-to-chatter-files/issues/9
        Boolean communitiesEnabled = ContentVersion.sObjectType.getDescribe().fields.getMap().containsKey( 'NetworkId' );

        // attachmentId ==> conversion result
        // as a map for easy retrieval throughout the various steps doing the conversion
        // and creation of content document links to share new file with parent record.
        // we update the message field on the result occasionally in subsequent steps
        Map<ID, ConversionResult> conversionResultsMap = new Map<ID, ConversionResult>();

        // identify if any of these attachment have already been converted
        Set<ID> alreadyConvertedAttachmentIds = filterAlreadyConvertedAttachmentIds( attachments );

        /*
         * Step 1
         * Convert Attachments to ContentVersions
         */

        List<ConversionRequest> conversionRequests = new List<ConversionRequest>();
        List<ContentVersion> contentVersions = new List<ContentVersion>();

        for ( Attachment att : attachments ) {

            // skip if we've already converted this record before
            if ( alreadyConvertedAttachmentIds.contains( att.id ) ) {
                continue;
            }

            // TODO implement more robust solution for customizing
            // conversion behavior on a per-object basis
            if ( EmailMessage.sObjectType != att.parentId.getSObjectType() && EmailTemplate.sObjectType != att.parentId.getSObjectType()) {

                // We set the owner of the new content file to be the
                // same as the attachment's creator because both fields
                // must have same value to insert the content file.
                // If they do not match then we get error:
                // "Documents in a user's private library must always be owned by that user."

                ContentVersion cv = new ContentVersion(
                    // data fields
                    versionData = att.body,
                    title = att.name,
                    description = att.description,
                    pathOnClient = '/' + att.name,
                    // audit fields
                    ownerId = att.createdById, // system requirement, owner and creator must be the same
                    createdById = att.createdById,
                    createdDate = att.createdDate,
                    lastModifiedById = att.lastModifiedById,
                    lastModifiedDate = att.lastModifiedDate,
                    // custom fields for history tracking and conversion purposes
                    original_record_id__c = att.id,
                    original_record_parent_id__c = att.parentId,
                    original_record_owner_id__c = att.ownerId
                );

                // if communities are enabled then assign network id
                if ( communitiesEnabled ) {
                    cv.put( 'NetworkId', this.networkId );
                }

                contentVersions.add( cv );

                conversionRequests.add( new ConversionRequest( att, cv ) );

            }

        }

        if ( contentVersions.size() > 0 ) {

            insert contentVersions;

            for ( ConversionRequest request : conversionRequests ) {

                ConversionResult result = new ConversionResult();
                result.success = true;
                result.contentVersionId = request.newFile.id;
                result.attachmentId = request.oldAttachment.id;

                conversionResultsMap.put( request.oldAttachment.id, result );

            }

            /*
             * Step 2
             * Requery ContentVersions to get latest published version id so that we can
             * know the generated content document id so that we can create
             * ContentDocumentLinks between the document and note's parent record and owner.
             * Doing so will share the new note so it's accessible by others.
             */

            Map<ID, ContentVersion> contentVersionsMap = new Map<ID, ContentVersion>([
                SELECT
                    id,
                    ownerId,
                    contentDocumentId,
                    original_record_id__c,
                    original_record_parent_id__c
                FROM
                    ContentVersion
                WHERE
                    id IN :contentVersions
            ]);

            System.assertEquals( contentVersions.size(), contentVersionsMap.size() );

            /*
             * Step 3
             * Create ContentDocumentLinks to share the new content
             * with the same parent record as the source attachment
             */

            List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();

            for ( ConversionRequest request : conversionRequests ) {

                ContentVersion cv = contentVersionsMap.get( request.newFile.id );

                // should converted file be shared with parent?
                if ( !request.oldAttachment.isPrivate || ( request.oldAttachment.isPrivate && this.options.sharePrivateAttachmentsWithParentRecord ) ) {

                    // share the new file with the same parent entity of the old attachment
                    // any user with visibility to this record has visibility to this file
                    contentDocumentLinks.add( new ContentDocumentLink(
                        linkedEntityId = request.oldAttachment.parentId,
                        contentDocumentId = cv.contentDocumentId,
                        shareType = this.options.shareType,
                        visibility = this.options.visibility
                    ));

                } else {

                    String message  = 'Not creating ContentDocumentLink to share ContentDocument (' + cv.contentDocumentId + ') with Parent Record (' + request.oldAttachment.parentId + ') because attachment record (' + request.oldAttachment.id + ') is private. ';
                           message += 'Either make attachment record not private or enable the [Share Private Attachments?] option and convert again, or manually update the new document\'s sharing settings.';

                    conversionResultsMap.get( request.oldAttachment.id ).message += ' ' + message;

                }

            }

            // create share links between new file and original attachment parent entity
            if ( contentDocumentLinks.size() > 0 ) {
                insert contentDocumentLinks;
            }

            // lastly, delete the original attachments that were successfully converted into files
            if ( this.options.deleteAttachmentsUponConversion ) {

                List<Attachment> attachmentsToDelete = new List<Attachment>();

                for ( ConversionRequest request : conversionRequests ) {
                    attachmentsToDelete.add( request.oldAttachment );
                }

                delete attachmentsToDelete;

            }

        }

        return conversionResultsMap.values();
    }

    /**
     * Given a list of attachments then returns the sublist of those
     * that have already been converted.
     */
    public Set<ID> filterAlreadyConvertedAttachmentIds( List<Attachment> attachments ) {

        Set<ID> filteredAttachmentIds = new Set<ID>();

        Set<ID> attachmentIds = new Set<ID>();
        Set<ID> parentIds = new Set<ID>();

        for ( Attachment att : attachments ) {
            attachmentIds.add( att.id );
            parentIds.add( att.parentId );
        }

        for ( List<ContentDocumentLink> links : [
            SELECT
                contentDocument.latestPublishedVersion.original_record_id__c
            FROM
                ContentDocumentLink
            WHERE
                linkedEntityId IN :parentIds
                AND
                contentDocument.latestPublishedVersion.original_record_id__c IN :attachmentIds
        ]) {

            for ( ContentDocumentLink link : links ) {

                if ( link.contentDocument != null && link.contentDocument.latestPublishedVersion != null ) {

                    if ( attachmentIds.contains( link.contentDocument.latestPublishedVersion.original_record_id__c ) ) {
                        filteredAttachmentIds.add( link.contentDocument.latestPublishedVersion.original_record_id__c );
                    }

                }

            }

        }

        return filteredAttachmentIds;
    }

    public class ConversionRequest {

        public Attachment oldAttachment { get; set; }

        public ContentVersion newFile { get; set; }

        public ConversionRequest( Attachment oldAttachment, ContentVersion newFile ) {
            this.oldAttachment = oldAttachment;
            this.newFile = newFile;
        }

    }

    public class ConversionResult {

        // true if attachment was converted; false otherwise
        public Boolean success { get; set; }

        // id of the attachment being converted, should always be populated
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