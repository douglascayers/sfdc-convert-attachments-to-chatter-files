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

        List<ContentVersion> contentVersions = new List<ContentVersion>();

        for ( Attachment att : attachments ) {

            // skip if we've already converted this record before
            if ( alreadyConvertedAttachmentIds.contains( att.id ) ) {
                continue;
            }

            // TODO implement more robust solution for customizing
            // conversion behavior on a per-object basis
            if ( EmailMessage.sObjectType != att.parentId.getSObjectType() ) {

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

            }

        }

        if ( contentVersions.size() > 0 ) {

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

                ConversionResult result = new ConversionResult();
                result.success = true;
                result.contentVersionId = contentVersions[i].id;
                result.attachmentId = attachments[i].id;

                conversionResultsMap.put( attachments[i].id, result );

            }

            /*
             * Step 2
             * Requery ContentVersions to get generated content document id (so we can link records to the content)
             * and the original attachment parent id (the record we want to share the content with)
             */

            contentVersions = [
                SELECT
                    id, ownerId, contentDocumentId, original_record_id__c, original_record_parent_id__c
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

            for ( ContentVersion cv : contentVersions ) {

                Attachment att = contentVersionToAttachmentsMap.get( cv.id );

                // should converted file be shared with parent?
                if ( !att.isPrivate || ( att.isPrivate && this.options.sharePrivateAttachmentsWithParentRecord ) ) {

                    // share the new file with the same parent entity of the old attachment
                    // any user with visibility to this record has visibility to this file
                    contentDocumentLinks.add( new ContentDocumentLink(
                        linkedEntityId = att.parentId,
                        contentDocumentId = cv.contentDocumentId,
                        shareType = options.shareType,
                        visibility = options.visibility
                    ));

                } else {

                    String message  = 'Not creating ContentDocumentLink to share ContentDocument (' + cv.contentDocumentId + ') with Parent Record (' + att.parentId + ') because attachment record (' + att.id + ') is private. ';
                           message += 'Either make attachment record not private or enable the [Share Private Attachments?] option and convert again, or manually update the new document\'s sharing settings.';

                    conversionResultsMap.get( att.id ).message += ' ' + message;

                }

            }

            // create share links between new file and original attachment parent entity
            if ( contentDocumentLinks.size() > 0 ) {
                insert contentDocumentLinks;
            }

            // lastly, delete the original attachments that were successfully converted into files
            if ( this.options.deleteAttachmentsUponConversion ) {

                List<Attachment> attachmentsToDelete = new List<Attachment>();

                for ( ContentVersion contentVersion : contentVersions ) {
                    attachmentsToDelete.add( new Attachment( id = contentVersion.original_record_id__c ) );
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

        Set<ID> attachmentIds = new Set<ID>();

        for ( Attachment att : attachments ) {
            attachmentIds.add( att.id );
        }

        return filterAlreadyConvertedAttachmentIds( attachmentIds );
    }

    /**
     * Given a set of attachment ids then returns the sublist of those
     * that have already been converted.
     */
    public Set<ID> filterAlreadyConvertedAttachmentIds( Set<ID> attachmentIds ) {

        Set<ID> filteredAttachmentIds = new Set<ID>();

        if ( attachmentIds != null && attachmentIds.size() > 0 ) {

            for ( List<ContentVersion> versions : [
                SELECT
                    original_record_id__c
                FROM
                    ContentVersion
                WHERE
                    original_record_id__c IN :attachmentIds
            ]) {

                for ( ContentVersion cv : versions ) {
                    filteredAttachmentIds.add( cv.original_record_id__c );
                }

            }

        }

        return filteredAttachmentIds;
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