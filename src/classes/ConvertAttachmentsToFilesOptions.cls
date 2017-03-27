/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Represents configuration options to pass to conversion service
 * to influence how the conversion will be handled with the attachments.
 */
public with sharing class ConvertAttachmentsToFilesOptions {

    // The ContentDocumentLink.ShareType value to use for converted files.
    // This controls user's view/edit ability of the file.
    //
    // Options:
    //     'V' = view only
    //     'I' = inferred view or edit based on user's similar access to related record
    //     'C' = collaborator, view and edit (not supported if related to standard object)
    //
    // The default is 'V'.
    //
    public String shareType { get; set; }

    // The ContentDocumentLink.Visibility value to use for converted files.
    // This controls whether file is visible to internal users only or all users.
    //
    // Options:
    //     'InternalUsers' = available only to internal users who have permission to see file
    //     'AllUsers' = available to all users, including community users, who have permission to see file
    //
    // If you have communities enabled then consider 'AllUsers' so those users don't lose access to the files.
    // If communities is enabled then default is 'InternalUsers', otherwise 'AllUsers' is only valid value.
    //
    public String visibility { get; set; }

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

    // Scope the conversion to just attachments related to specific records
    // if null then ALL attachments in the system will be converted
    // if empty then NO attachments will be converted
    // if non-empty then only attachments related to those records will be converted
    public Set<ID> parentIds { get; set; }

    public ConvertAttachmentsToFilesOptions() {
        this( Convert_Attachments_to_Files_Settings__c.getInstance() );
    }

    public ConvertAttachmentsToFilesOptions( Convert_Attachments_to_Files_Settings__c settings ) {
        this.shareType = settings.share_type__c;
        this.visibility = settings.visibility__c;
        this.deleteAttachmentsUponConversion = settings.delete_attachment_once_converted__c;
        this.sharePrivateAttachmentsWithParentRecord = settings.share_private_attachments__c;
        this.parentIds = null;
    }

}