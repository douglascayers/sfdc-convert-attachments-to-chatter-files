/**
 * Developed by Doug Ayers (douglascayers.com)
 */
public with sharing class ConvertAttachmentsScheduleController {

    public Convert_Attachments_to_Files_Settings__c settings { get; set; }

    public String message { get; set; }

    public Boolean success { get; set; }

    public ConvertAttachmentsScheduleController() {

        this.settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();

    }

    public void save() {

        SavePoint sp = Database.setSavePoint();

        ID originalId = this.settings.id;

        try {

            upsert this.settings;

            this.message = 'Settings saved successfully!';
            this.success = true;

        } catch ( Exception e ) {

            System.debug( LoggingLevel.ERROR, e.getMessage() + ' : ' + e.getStackTraceString() );

            Database.rollback( sp );

            this.settings.id = originalId;

            this.message = e.getMessage();
            this.success = false;

        }

    }

}