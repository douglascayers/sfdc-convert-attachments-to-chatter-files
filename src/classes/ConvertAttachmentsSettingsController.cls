/**
 * Developed by Doug Ayers (douglascayers.com)
 */
public with sharing class ConvertAttachmentsSettingsController {

    public Convert_Attachments_to_Files_Settings__c settings { get; set; }

    public String message { get; set; }

    public Boolean success { get; set; }

    public Boolean isCommunitiesEnabled {
        get {
            return Schema.getGlobalDescribe().containsKey( 'Network' );
        }
    }

    public ConvertAttachmentsSettingsController() {

        this.settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();

    }

    public void save() {

        SavePoint sp = Database.setSavePoint();

        ID originalId = this.settings.id;

        try {

            if ( settings.Delete_Attachment_Once_Converted__c == null ||
                 settings.Share_Private_Attachments__c == null ||
                 settings.Share_Type__c == null ||
                 settings.Visibility__c == null
            ) {

                this.success = false;
                this.message = 'Please answer all questions to configure conversion options.';

            } else {

                upsert this.settings;

                // refresh any values set on insert
                this.settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();

                this.message = 'Settings saved successfully!';
                this.success = true;

            }

        } catch ( Exception e ) {

            System.debug( LoggingLevel.ERROR, e.getMessage() + ' : ' + e.getStackTraceString() );

            Database.rollback( sp );

            this.settings.id = originalId;

            this.message = e.getMessage();
            this.success = false;

        }

    }

}