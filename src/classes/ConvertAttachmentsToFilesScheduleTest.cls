/**
 * Developed by Doug Ayers (douglascayers.com)
 */
@isTest
private class ConvertAttachmentsToFilesScheduleTest {

    @isTest
    static void test_schedulable() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Share_Private_Attachments__c = true;

        upsert settings;

        Test.startTest();

        System.schedule( 'Conversion Job', '0 0 13 * * ?', new ConvertAttachmentsToFilesSchedulable() );

        Test.stopTest();

        System.assertEquals( 0, [ SELECT count() FROM Convert_Attachments_to_Files_Log__c ] );

    }

    @isTest
    static void test_errors() {

        ConvertAttachmentsToFilesSchedulable job = new ConvertAttachmentsToFilesSchedulable();

        job.batchSize = null; // will cause error

        Test.startTest();

        System.schedule( 'Conversion Job', '0 0 13 * * ?', job );

        Test.stopTest();

        System.assertEquals( 1, [ SELECT count() FROM Convert_Attachments_to_Files_Log__c ] );

    }

}