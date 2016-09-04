/**
 * Represents configuration options to pass to conversion service
 * to influence how the conversion will be handled with the attachments.
 */
public class ConvertAttachmentsToFilesOptions {

    // Should the Attachments be deleted upon conversion to ContentVersion?
    // Deleting them reduces redundant data storage.
    // Make sure you've backed up your data before enabling this.
    public Boolean deleteAttachmentsUponConversion { get; set; }

    // Classic Attachments have a 'IsPrivate' field that when checked the attachment
    // is only visible to the owner and administrators. To preserve this
    // then the new ContentVersion cannot be shared with the parent record
    // because doing so would grant any user who has at least read access
    // to the record to now have read access to the previously private attachment content.
    // The alternative is to still convert the attachment but don't share it with the
    // parent record; however, now the new Files are not categorized at all
    // so these now technically private new Files have no context beyond their content.
    // As with the delete option, I err on the side of caution and do nothing unless you enable this option.
    public Boolean sharePrivateAttachmentsWithParentRecord { get; set; }

    // ContentDocumentLink records cannot be linked with records whose object type
    // does not support Chatter Feed Tracking. This option indicates whether to
    // skip those attachments related to non-feed-tracking parents (false) or
    // to go ahead and convert them (true) but the File won't be shared to any records.
    // Only the file owner and administrator will have access to the file.
    public Boolean convertIfFeedTrackingDisabledOnParentObject { get; set; }

    // Should Attachments of EmailMessage records related to Cases be converted to Files?
    // The File will belong at the Case level. Only applies to Incoming Emails for Email-to-Case.
    public Boolean convertInboundEmailMessageAttachmentsToFilesOnCases { get; set; }

    // Scope the conversion to just attachments related to specific records
    // if null then ALL attachments in the system will be converted
    // if empty then NO attachments will be converted
    // if non-empty then only attachments related to those records will be converted
    public Set<ID> parentIds { get; set; }

    public ConvertAttachmentsToFilesOptions() {
        this.deleteAttachmentsUponConversion = false;
        this.sharePrivateAttachmentsWithParentRecord = false;
        this.convertIfFeedTrackingDisabledOnParentObject = false;
        this.convertInboundEmailMessageAttachmentsToFilesOnCases = false;
        this.parentIds = null;
    }

    public ConvertAttachmentsToFilesOptions( Convert_Attachments_to_Files_Settings__c settings ) {
        this.deleteAttachmentsUponConversion = settings.delete_attachment_once_converted__c;
        this.sharePrivateAttachmentsWithParentRecord = settings.share_private_attachments__c;
        this.convertIfFeedTrackingDisabledOnParentObject = settings.convert_if_feed_tracking_disabled__c;
        this.convertInboundEmailMessageAttachmentsToFilesOnCases = settings.convert_inbound_email_attachments__c;
        this.parentIds = null;
    }

}