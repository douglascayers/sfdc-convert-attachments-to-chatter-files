/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Work horse that does the actual attachment to file conversion.
 *
 * Uses 'without sharing' to ensure can perform SOQL queries on
 * existing ContentVersions and ContentDocumentLinks to know if
 * an Attachment has already been converted or not.
 */
public without sharing class ConvertAttachmentsToFilesService {

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

    // -----------------------------------------------------------------

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
    public List<ConversionResult> convert( List<Attachment> oldAttachments ) {

        // determine if communities are enabled and if so then we will need
        // to assign the network id field when inserting the content versions
        // otherwise error "INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY" occurs
        // if community user uploads an attachment and it tries to get converted
        // https://github.com/DouglasCAyers/sfdc-convert-attachments-to-chatter-files/issues/9
        Boolean communitiesEnabled = ContentVersion.sObjectType.getDescribe().fields.getMap().containsKey( 'NetworkId' );

        // identify if any of these attachments have already been converted
        Map<ID, ID> alreadyConvertedAttachmentIdsMap = getAlreadyConvertedAttachmentIdsMap( oldAttachments );

        Map<ID, Attachment> oldAttachmentsMap = new Map<ID, Attachment>( oldAttachments );

        // map of old attachment id to conversion result
        Map<ID, ConversionResult> conversionResultsMap = new Map<ID, ConversionResult>();

        // the new files to try and save
        List<ContentVersion> newFileVersions = new List<ContentVersion>();

        for ( Attachment oldAttachment : oldAttachments ) {

            // skip if we've already converted this record before
            if ( alreadyConvertedAttachmentIdsMap.containsKey( oldAttachment.id ) ) {

                ConversionResult conversionResult = new ConversionResult();
                conversionResult.status = ConversionResultStatus.SKIPPED;
                conversionResult.oldAttachment = oldAttachment;
                conversionResult.contentVersionId = alreadyConvertedAttachmentIdsMap.get( oldAttachment.id );
                conversionResult.message = 'Already converted.';

                conversionResultsMap.put( oldAttachment.id, conversionResult );

                continue;

            }

            // TODO implement more robust solution for customizing
            // conversion behavior on a per-object basis
            if ( EmailMessage.sObjectType == oldAttachment.parentId.getSObjectType() || EmailTemplate.sObjectType == oldAttachment.parentId.getSObjectType() ) {

                ConversionResult conversionResult = new ConversionResult();
                conversionResult.status = ConversionResultStatus.SKIPPED;
                conversionResult.oldAttachment = oldAttachment;
                conversionResult.contentVersionId = alreadyConvertedAttachmentIdsMap.get( oldAttachment.id );
                conversionResult.message = 'Parent object type [' + oldAttachment.parentId.getSobjectType() + '] does not support ContentVersions.';

                conversionResultsMap.put( oldAttachment.id, conversionResult );

                continue;

            }

            // We set the owner of the new content file to be the
            // same as the attachment's owner because both fields
            // must have same value to insert the content file.
            // If they do not match then we get error:
            // "Documents in a user's private library must always be owned by that user."
            // The other reason to reference the old record's owner
            // is if the original creator is inactive and the admin
            // needs the new converted file to be owned by an active user.
            // The owner of records can be changed, the created by cannot.

            ContentVersion newFileVersion = new ContentVersion(
                // data fields
                versionData = oldAttachment.body,
                title = oldAttachment.name,
                description = oldAttachment.description,
                pathOnClient = '/' + oldAttachment.name,
                firstPublishLocationId = oldAttachment.parentId,
                sharingPrivacy = ( oldAttachment.isPrivate ? 'P' : 'N' ),
                // audit fields
                ownerId = oldAttachment.ownerId, // system requirement, owner and creator must be the same
                createdById = oldAttachment.ownerId,
                createdDate = oldAttachment.createdDate,
                lastModifiedById = oldAttachment.lastModifiedById,
                lastModifiedDate = oldAttachment.lastModifiedDate,
                // custom fields for history tracking and conversion purposes
                original_record_id__c = oldAttachment.id,
                original_record_parent_id__c = oldAttachment.parentId,
                original_record_owner_id__c = oldAttachment.ownerId
            );

            // if communities are enabled then assign network id
            if ( communitiesEnabled ) {
                newFileVersion.put( 'NetworkId', this.networkId );
            }

            newFileVersions.add( newFileVersion );

        }

        if ( newFileVersions.size() > 0 ) {

            SavePoint sp = Database.setSavepoint();

            try {

                Database.DMLOptions dmo = new Database.DMLOptions();
                dmo.optAllOrNone = false;

                List<Database.SaveResult> saveResults = Database.insert( newFileVersions, dmo );

                for ( Integer i = 0; i < saveResults.size(); i++ ) {

                    Database.SaveResult saveResult = saveResults[i];

                    Attachment oldAttachment = oldAttachmentsMap.get( newFileVersions[i].original_record_id__c );

                    ConversionResult conversionResult = new ConversionResult();
                    conversionResult.status = ( saveResult.isSuccess() ? ConversionResultStatus.CONVERTED : ConversionResultStatus.ERROR );
                    conversionResult.contentVersionId = saveResult.getId();
                    conversionResult.oldAttachment = oldAttachment;

                    if ( !saveResult.isSuccess() ) {

                        List<String> messages = new List<String>();

                        for ( Database.Error err : saveResult.getErrors() ) {
                            messages.add( err.getMessage() );
                        }

                        conversionResult.message = String.join( messages, ' ' );

                    }

                    conversionResultsMap.put( oldAttachment.id, conversionResult );

                }

                postProcessConversionResults( conversionResultsMap );

            } catch ( Exception e ) {

                Database.rollback( sp );
                throw e;

            }

        }

        // sort map values in same order as attachments parameter
        List<ConversionResult> conversionResults = new List<ConversionResult>();
        for ( Attachment oldAttachment : oldAttachments ) {
            conversionResults.add( conversionResultsMap.get( oldAttachment.id ) );
        }

        return conversionResults;
    }

    // -----------------------------------------------------------------

    private void postProcessConversionResults( Map<ID, ConversionResult> conversionResultsMap ) {

        // should we delete the converted attachments?
        if ( this.options.deleteAttachmentsUponConversion ) {
            deleteConvertedAttachments( conversionResultsMap );
        }

    }

    // -----------------------------------------------------------------

    private void deleteConvertedAttachments( Map<ID, ConversionResult> conversionResultsMap ) {

        List<Attachment> attachmentsToDelete = new List<Attachment>();

        for ( ConversionResult conversionResult : conversionResultsMap.values() ) {
            if ( conversionResult.status == ConversionResultStatus.CONVERTED ) {
                    attachmentsToDelete.add( conversionResult.oldAttachment );
            }
        }

        if ( attachmentsToDelete.size() > 0 ) {
            delete attachmentsToDelete;
        }

    }

    // -----------------------------------------------------------------

    /**
     * Given a list of attachments then returns the submap of those
     * that have already been converted and their new file ids.
     */
    public Map<ID, ID> getAlreadyConvertedAttachmentIdsMap( List<Attachment> attachments ) {

        // map of old attachment ids to new file ids
        Map<ID, ID> convertedAttachmentIdsMap = new Map<ID, ID>();

        Set<ID> attachmentIds = new Set<ID>();
        Set<ID> parentIds = new Set<ID>();

        for ( Attachment att : attachments ) {
            attachmentIds.add( att.id );
            parentIds.add( att.parentId );
        }

        for ( List<ContentDocumentLink> links : [
            SELECT
                contentDocument.latestPublishedVersionId,
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
                        convertedAttachmentIdsMap.put( link.contentDocument.latestPublishedVersion.original_record_id__c, link.contentDocument.latestPublishedVersionId );
                    }

                }

            }

        }

        return convertedAttachmentIdsMap;
    }

    // -----------------------------------------------------------------

    public class ConversionResult {

        // was conversion success? skipped? error?
        public ConversionResultStatus status { get; set; }

        // the old attachment to convert
        public Attachment oldAttachment { get; set; }

        // id of the newly converted file if conversion success
        public ID contentVersionId { get; set; }

        // any pertinent message
        public String message { get; set; }

        public ConversionResult() {
            this.message = '';
        }

    }

    public enum ConversionResultStatus {
        CONVERTED, SKIPPED, ERROR
    }

}