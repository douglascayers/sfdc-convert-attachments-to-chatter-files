/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Represents configuration options to pass to conversion service
 * to influence how the conversion will be handled with the attachments.
 */
public with sharing class ConvertAttachmentsToFilesOptions {

    // Should the Attachments be deleted upon conversion to ContentVersion?
    // Deleting them reduces redundant data storage.
    // Make sure you've backed up your data before enabling this.
    public Boolean deleteAttachmentsUponConversion { get; set; }

    // To help mitigate hitting the max content publication limit then
    // admins can specify their own soft limit to, hopefully, predictably
    // stop the conversion job prior to hitting the governor limit
    public Integer maxRecordsToConvert { get; set; }

    // Scope the conversion to just attachments related to specific records
    // if null then ALL attachments in the system will be converted
    // if empty then NO attachments will be converted
    // if non-empty then only attachments related to those records will be converted
    public Set<ID> parentIds { get; set; }

    public ConvertAttachmentsToFilesOptions() {
        this( Convert_Attachments_to_Files_Settings__c.getInstance() );
    }

    public ConvertAttachmentsToFilesOptions( Convert_Attachments_to_Files_Settings__c settings ) {
        this.deleteAttachmentsUponConversion = settings.delete_attachment_once_converted__c;
        this.maxRecordsToConvert = 150000;
        this.parentIds = null;
    }

}