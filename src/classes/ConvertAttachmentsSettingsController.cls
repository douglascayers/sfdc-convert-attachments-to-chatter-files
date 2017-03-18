public with sharing class ConvertAttachmentsSettingsController {

    public Convert_Attachments_to_Files_Settings__c settings { get; set; }

    public String saveMessage { get; set; }
    public Boolean saveSuccess { get; set; }

    public ConvertAttachmentsSettingsController() {

        this.settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();

    }

    public void save() {

        SavePoint sp = Database.setSavePoint();

        ID originalId = this.settings.id;

        try {

            upsert this.settings;

            this.saveMessage = 'Settings saved successfully!';
            this.saveSuccess = true;

        } catch ( Exception e ) {

            System.debug( LoggingLevel.ERROR, e.getMessage() + ' : ' + e.getStackTraceString() );

            Database.rollback( sp );

            this.settings.id = originalId;

            this.saveMessage = e.getMessage();
            this.saveSuccess = false;

        }

    }

}