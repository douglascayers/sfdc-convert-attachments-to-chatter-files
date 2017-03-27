/**
 * Developed by Doug Ayers (douglascayers.com)
 */
@isTest
private class ConvertAttachmentsSettingsControllerTest {

    @isTest
    static void test_communities_enabled() {

        Test.startTest();

        ConvertAttachmentsSettingsController controller = new ConvertAttachmentsSettingsController();

        Boolean isCommunitiesEnabled = controller.isCommunitiesEnabled;

        Test.stopTest();

        System.assertEquals( Schema.getGlobalDescribe().containsKey( 'Network' ), isCommunitiesEnabled );

    }

    @isTest
    static void test_save_new_settings() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Share_Private_Attachments__c = true;

        Test.startTest();

        ConvertAttachmentsSettingsController controller = new ConvertAttachmentsSettingsController();

        controller.settings = settings;

        controller.save();

        Test.stopTest();

        System.assertEquals( true, controller.success );
        System.assert( controller.message.containsIgnoreCase( 'Settings saved successfully' ) );

    }

    @isTest
    static void test_update_existing_settings() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Share_Private_Attachments__c = true;

        upsert settings;

        Test.startTest();

        ConvertAttachmentsSettingsController controller = new ConvertAttachmentsSettingsController();

        controller.settings = settings;

        controller.save();

        Test.stopTest();

        System.assertEquals( true, controller.success );
        System.assert( controller.message.containsIgnoreCase( 'Settings saved successfully' ) );

    }

    @isTest
    static void test_save_error() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Share_Private_Attachments__c = true;

        upsert settings;

        Test.startTest();

        ConvertAttachmentsSettingsController controller = new ConvertAttachmentsSettingsController();

        controller.settings = settings;

        // leave fields blank, cause validation errors
        controller.settings.visibility__c = null;

        controller.save();

        System.assertEquals( false, controller.success );
        System.assert( controller.message.containsIgnoreCase( 'Please answer all questions' ) );

        // fix validation error
        controller.settings.visibility__c = 'AllUsers';

        delete settings; // will cause exception on save because ID field is still populated on controller's reference

        controller.save();

        Test.stopTest();

        System.assertEquals( false, controller.success );

    }

}