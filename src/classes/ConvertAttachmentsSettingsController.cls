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

    // this option combines two setting fields for whether or not to
    // actually convert private attachments, and if yes, how to share them.
    // based on the submitted value then settings.Convert_Private_Attachments__c and settings.Share_Private_Attachments__c
    // will be assigned their true/false values.
    // this allows us to have one radio button on the vf page even though stored in two fields in database
    public String convertAndSharePrivateAttachments { get; set; }

    public String message { get; set; }

    public Boolean success { get; set; }

    public ConvertAttachmentsSettingsController() {

        this.settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        this.convertAndSharePrivateAttachments = inferConvertAndSharePrivateAttachments( this.settings );

    }

    public void save() {

        SavePoint sp = Database.setSavePoint();

        ID originalId = this.settings.id;

        try {

            applyConvertAndSharePrivateAttachments( this.settings, this.convertAndSharePrivateAttachments );

            Boolean isFormValid = (
                this.settings.Delete_Attachment_Once_Converted__c != null &&
                this.settings.Convert_Private_Attachments__c != null &&
                this.settings.Share_Private_Attachments__c != null
            );

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

    /**
     * Based on Convert_Private_Attachments__c and Share_Private_Attachments__c will return one of three values:
     *  1. yes_convert_yes_share
     *  2. yes_convert_no_share
     *  3. no_convert_no_share
     */
    @TestVisible
    private String inferConvertAndSharePrivateAttachments( Convert_Attachments_to_Files_Settings__c settings ) {

        String value = 'no_convert_no_share';

        if ( settings.Convert_Private_Attachments__c ) {
            if ( settings.Share_Private_Attachments__c ) {
                value = 'yes_convert_yes_share';
            } else {
                value = 'yes_convert_no_share';
            }
        }

        return value;
    }

    /**
     * Based on the value of the 'convertAndSharePrivateAttachments' string this method
     * assigns true/false to the setting's Convert_Private_Attachments__c and Share_Private_Attachments__c fields.
     */
    @TestVisible
    private void applyConvertAndSharePrivateAttachments( Convert_Attachments_to_Files_Settings__c settings, String convertAndSharePrivateAttachments ) {

        if ( convertAndSharePrivateAttachments == 'yes_convert_yes_share' ) {
            settings.Convert_Private_Attachments__c = true;
            settings.Share_Private_Attachments__c = true;
        } else if ( convertAndSharePrivateAttachments == 'yes_convert_no_share' ) {
            settings.Convert_Private_Attachments__c = true;
            settings.Share_Private_Attachments__c = false;
        } else {
            settings.Convert_Private_Attachments__c = false;
            settings.Share_Private_Attachments__c = false;
        }

    }

}