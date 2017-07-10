/**
 * Developed by Doug Ayers (douglascayers.com)
 */
@isTest
private class ConvertAttachmentsRunOnceControllerTest {

    @isTest
    static void test_convert_all() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Convert_Private_Attachments__c = true;
        settings.Share_Private_Attachments__c = true;

        upsert settings;

        Account acct1 = new Account(
            name = 'Test Account 1'
        );

        insert acct1;

        Account acct2 = new Account(
            name = 'Test Account 2'
        );

        insert acct2;

        Attachment attachment1 = new Attachment(
            name = 'Hello World 1.txt',
            body = Blob.valueOf('Hello World 1'),
            parentId = acct1.id
        );

        insert attachment1;

        Attachment attachment2 = new Attachment(
            name = 'Hello World 2.txt',
            body = Blob.valueOf('Hello World 2'),
            parentId = acct2.id
        );

        insert attachment2;

        Test.startTest();

        ConvertAttachmentsRunOnceController controller = new ConvertAttachmentsRunOnceController();

        controller.submitJob();

        Test.stopTest();

        System.assertEquals( true, controller.success );
        System.assert( controller.message.containsIgnoreCase( 'Conversion batch job submitted' ) );

        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct1.id AND contentDocument.latestPublishedVersion.original_record_id__c = :attachment1.id ] );
        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct2.id AND contentDocument.latestPublishedVersion.original_record_id__c = :attachment2.id ] );

    }

    @isTest
    static void test_convert_one() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Convert_Private_Attachments__c = true;
        settings.Share_Private_Attachments__c = true;

        upsert settings;

        Account acct1 = new Account(
            name = 'Test Account 1'
        );

        insert acct1;

        Account acct2 = new Account(
            name = 'Test Account 2'
        );

        insert acct2;

        Attachment attachment1 = new Attachment(
            name = 'Hello World 1.txt',
            body = Blob.valueOf('Hello World 1'),
            parentId = acct1.id
        );

        insert attachment1;

        Attachment attachment2 = new Attachment(
            name = 'Hello World 2.txt',
            body = Blob.valueOf('Hello World 2'),
            parentId = acct2.id
        );

        insert attachment2;

        Test.startTest();

        ConvertAttachmentsRunOnceController controller = new ConvertAttachmentsRunOnceController();
        controller.parentIdsCsv = acct1.id + ',' + acct1.id; // same id, comma separated to test split

        controller.submitJob();

        Test.stopTest();

        System.assertEquals( true, controller.success );
        System.assert( controller.message.containsIgnoreCase( 'Conversion batch job submitted' ) );

        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct1.id AND contentDocument.latestPublishedVersion.original_record_id__c = :attachment1.id ] );
        System.assertEquals( 0, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct2.id AND contentDocument.latestPublishedVersion.original_record_id__c = :attachment2.id ] );

    }

    @isTest
    static void test_convert_error() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Convert_Private_Attachments__c = true;
        settings.Share_Private_Attachments__c = true;

        upsert settings;

        Account acct1 = new Account(
            name = 'Test Account 1'
        );

        insert acct1;

        Account acct2 = new Account(
            name = 'Test Account 2'
        );

        insert acct2;

        Attachment attachment1 = new Attachment(
            name = 'Hello World 1.txt',
            body = Blob.valueOf('Hello World 1'),
            parentId = acct1.id
        );

        insert attachment1;

        Attachment attachment2 = new Attachment(
            name = 'Hello World 2.txt',
            body = Blob.valueOf('Hello World 2'),
            parentId = acct2.id
        );

        insert attachment2;

        Test.startTest();

        ConvertAttachmentsRunOnceController controller = new ConvertAttachmentsRunOnceController();
        controller.batchSize = -10; // negative, should cause error

        controller.submitJob();

        Test.stopTest();

        System.assertEquals( false, controller.success );

        System.assertEquals( 0, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct1.id AND contentDocument.latestPublishedVersion.original_record_id__c = :attachment1.id ] );
        System.assertEquals( 0, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct2.id AND contentDocument.latestPublishedVersion.original_record_id__c = :attachment2.id ] );

    }

}