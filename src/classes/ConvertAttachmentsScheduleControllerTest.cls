/**
 * Developed by Doug Ayers (douglascayers.com)
 */
@isTest
private class ConvertAttachmentsScheduleControllerTest {

    @isTest
    static void test_save_new_settings() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;

        Test.startTest();

        ConvertAttachmentsScheduleController controller = new ConvertAttachmentsScheduleController();

        controller.settings = settings;

        controller.save();

        Test.stopTest();

        System.assertEquals( true, controller.success );
        System.assert( controller.message.containsIgnoreCase( 'Settings saved successfully' ) );

    }

    @isTest
    static void test_update_existing_settings() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;

        upsert settings;

        Test.startTest();

        ConvertAttachmentsScheduleController controller = new ConvertAttachmentsScheduleController();

        controller.settings = settings;

        controller.save();

        Test.stopTest();

        System.assertEquals( true, controller.success );
        System.assert( controller.message.containsIgnoreCase( 'Settings saved successfully' ) );

    }

    @isTest
    static void test_save_error() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;

        upsert settings;

        Test.startTest();

        ConvertAttachmentsScheduleController controller = new ConvertAttachmentsScheduleController();

        controller.settings = settings;

        delete settings; // will cause error on save because ID field is still populated on controller's reference

        controller.save();

        Test.stopTest();

        System.assertEquals( false, controller.success );

    }

}