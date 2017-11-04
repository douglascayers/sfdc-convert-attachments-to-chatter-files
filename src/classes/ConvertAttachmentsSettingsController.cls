/**
 * Developed by Doug Ayers (douglascayers.com)
 */
public with sharing class ConvertAttachmentsSettingsController {

    @TestVisible
    private Boolean mockIsFormValid { get; set; }

    @TestVisible
    private Exception mockException { get; set; }

    // ----------------------------------------------------------------------

    public Convert_Attachments_to_Files_Settings__c settings { get; set; }

    public String message { get; set; }

    public Boolean success { get; set; }

    public ConvertAttachmentsSettingsController() {
        this.settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
    }

    public void save() {

        SavePoint sp = Database.setSavePoint();

        ID originalId = this.settings.id;

        try {

            Boolean isFormValid = ( this.settings.Delete_Attachment_Once_Converted__c != null );

            if ( Test.isRunningTest() ) {

                if ( this.mockException != null ) {
                    throw this.mockException;
                }

                if ( this.mockIsFormValid != null ) {
                    isFormValid = this.mockIsFormValid;
                }

            }

            if ( isFormValid ) {

                upsert this.settings;

                // refresh any values set on insert
                this.settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();

                this.message = 'Settings saved successfully!';
                this.success = true;

            } else {

                this.success = false;
                this.message = 'Please answer all questions to configure conversion options.';

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