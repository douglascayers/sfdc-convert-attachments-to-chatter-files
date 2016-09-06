/**
 * Represents configuration options to pass to conversion service
 * to influence how the conversion will be handled with the notes.
 */
public class ConvertNotesToContentNotesOptions {

    // Should the Notes be deleted upon conversion to ContentNote?
    // Deleting them reduces redundant data storage.
    // Make sure you've backed up your data before enabling this.
    public Boolean deleteNotesUponConversion { get; set; }

    // Classic Notes have a 'IsPrivate' field that when checked the note
    // is only visible to the owner and administrators. To preserve this
    // then the new ContentNote cannot be shared with the parent record
    // because doing so would grant any user who has at least read access
    // to the record to now have read access to the previously private note content.
    // The alternative is to still convert the note but don't share it with the
    // parent record; however, now the new Notes are not categorized at all
    // so these now technically private new Notes have no context beyond their content.
    // As with the delete option, I err on the side of caution and do nothing unless you enable this option.
    public Boolean sharePrivateNotesWithParentRecord { get; set; }

    // ContentDocumentLink records cannot be linked with records whose object type
    // does not support Chatter Feed Tracking. This option indicates whether to
    // skip those notes related to non-feed-tracking parents (false) or
    // to go ahead and convert them (true) but the ContentNote won't be shared to any records.
    // Only the new note owner and administrator will have access to the new note.
    public Boolean convertIfFeedTrackingDisabledOnParentObject { get; set; }

    // Email addresses to send conversion result information to after a batch of notes are converted to files.
    public List<String> conversionResultEmailNotificationAddresses { get; set; }

    // Scope the conversion to just notes related to specific records
    // if null then ALL notes in the system will be converted
    // if empty then NO notes will be converted
    // if non-empty then only notes related to those records will be converted
    public Set<ID> parentIds { get; set; }

    public ConvertNotesToContentNotesOptions() {
        this.deleteNotesUponConversion = false;
        this.sharePrivateNotesWithParentRecord = false;
        this.convertIfFeedTrackingDisabledOnParentObject = false;
        this.conversionResultEmailNotificationAddresses = null;
        this.parentIds = null;
    }

    public ConvertNotesToContentNotesOptions( Convert_Notes_to_ContentNotes_Settings__c settings ) {
        this.deleteNotesUponConversion = settings.delete_note_once_converted__c;
        this.sharePrivateNotesWithParentRecord = settings.share_private_notes__c;
        this.convertIfFeedTrackingDisabledOnParentObject = settings.convert_if_feed_tracking_disabled__c;
        this.conversionResultEmailNotificationAddresses = null;
        this.parentIds = null;

        if ( String.isNotBlank( settings.conversion_result_email_notifications__c ) ) {
            this.conversionResultEmailNotificationAddresses = settings.conversion_result_email_notifications__c.split(',');
        }

    }

}