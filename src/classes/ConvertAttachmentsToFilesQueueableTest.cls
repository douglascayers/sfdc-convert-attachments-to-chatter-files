/**
 * Developed by Doug Ayers (douglascayers.com)
 */
@isTest
private class ConvertAttachmentsToFilesQueueableTest {

    @isTest
    static void test_queueable_with_options() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;

        upsert settings;

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account acct1 = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert acct1;

        Attachment attachment1 = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf('Hello World'),
            parentId = acct1.id,
            ownerId = user1.id
        );

        insert attachment1;

        Test.startTest();

        ConvertAttachmentsToFilesQueueable queueable = new ConvertAttachmentsToFilesQueueable(
            new Set<ID>{ attachment1.id },
            new ConvertAttachmentsToFilesOptions( settings )
        );

        System.enqueueJob( queueable );

        Test.stopTest();

        for ( Convert_Attachments_to_Files_Log__c log : [ SELECT Status__c, Old_Attachment_ID__c, New_File_ID__c, Summary__c, Detail__c FROM Convert_Attachments_to_Files_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct1.id ] );
        System.assertEquals( 0, [ SELECT count() FROM Note WHERE id = :attachment1.id ] );

        ContentDocumentLink cdl_file1 = [
            SELECT
                id,
                contentDocumentId,
                contentDocument.fileType,
                contentDocument.latestPublishedVersion.original_record_id__c,
                contentDocument.latestPublishedVersion.original_record_parent_id__c,
                contentDocument.latestPublishedVersion.original_record_owner_id__c
            FROM
                ContentDocumentLink
            WHERE
            linkedEntityId = :acct1.id
            AND
            contentDocument.latestPublishedVersion.original_record_id__c = :attachment1.id
        ];

        System.assertEquals( 'TEXT', cdl_file1.contentDocument.fileType );
        System.assertEquals( attachment1.id, cdl_file1.contentDocument.latestPublishedVersion.original_record_id__c );
        System.assertEquals( attachment1.parentId, cdl_file1.contentDocument.latestPublishedVersion.original_record_parent_id__c );
        System.assertEquals( attachment1.ownerId, cdl_file1.contentDocument.latestPublishedVersion.original_record_owner_id__c );

    }

    @isTest
    static void test_queueable_without_options() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = false;

        upsert settings;

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account acct1 = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert acct1;

        Attachment attachment1 = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf('Hello World'),
            parentId = acct1.id,
            ownerId = user1.id
        );

        insert attachment1;

        Test.startTest();

        ConvertAttachmentsToFilesQueueable queueable = new ConvertAttachmentsToFilesQueueable(
            new Set<ID>{ attachment1.id }
        );

        System.enqueueJob( queueable );

        Test.stopTest();

        for ( Convert_Attachments_to_Files_Log__c log : [ SELECT Status__c, Old_Attachment_ID__c, New_File_ID__c, Summary__c, Detail__c FROM Convert_Attachments_to_Files_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct1.id ] );
        System.assertEquals( 0, [ SELECT count() FROM Note WHERE id = :attachment1.id ] );

        ContentDocumentLink cdl_file1 = [
            SELECT
                id,
                contentDocumentId,
                contentDocument.fileType,
                contentDocument.latestPublishedVersion.original_record_id__c,
                contentDocument.latestPublishedVersion.original_record_parent_id__c,
                contentDocument.latestPublishedVersion.original_record_owner_id__c
            FROM
                ContentDocumentLink
            WHERE
            linkedEntityId = :acct1.id
            AND
            contentDocument.latestPublishedVersion.original_record_id__c = :attachment1.id
        ];

        System.assertEquals( 'TEXT', cdl_file1.contentDocument.fileType );
        System.assertEquals( attachment1.id, cdl_file1.contentDocument.latestPublishedVersion.original_record_id__c );
        System.assertEquals( attachment1.parentId, cdl_file1.contentDocument.latestPublishedVersion.original_record_parent_id__c );
        System.assertEquals( attachment1.ownerId, cdl_file1.contentDocument.latestPublishedVersion.original_record_owner_id__c );

    }

    @isTest
    static void test_conversion_error() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;

        upsert settings;

        Account acct1 = new Account(
            name = 'Test Account'
        );

        insert acct1;

        Attachment attachment1 = new Attachment(
            name = 'Hello World 1.txt',
            body = Blob.valueOf('Hello World 1'),
            parentId = acct1.id
        );

        insert attachment1;

        Test.startTest();

        ConvertAttachmentsToFilesService.ConversionResult mockResult = new ConvertAttachmentsToFilesService.ConversionResult();
        mockResult.status = ConvertAttachmentsToFilesService.ConversionResultStatus.ERROR;
        mockResult.message = 'Mock Error Result';
        mockResult.oldAttachment = attachment1;

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions( settings );

        ConvertAttachmentsToFilesQueueable queueable = new ConvertAttachmentsToFilesQueueable(
            new Set<ID>{ attachment1.id }
        );

        queueable.mockResults = new List<ConvertAttachmentsToFilesService.ConversionResult>{ mockResult };

        System.enqueueJob( queueable );

        Test.stopTest();

        for ( Convert_Attachments_to_Files_Log__c log : [ SELECT Status__c, Old_Attachment_ID__c, New_File_ID__c, Summary__c, Detail__c FROM Convert_Attachments_to_Files_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 1, [ SELECT count() FROM Convert_Attachments_to_Files_Log__c WHERE old_attachment_id__c = :attachment1.id AND status__c = 'ERROR' ] );

    }

    @isTest
    static void test_conversion_exception() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;

        upsert settings;

        Account acct1 = new Account(
            name = 'Test Account'
        );

        insert acct1;

        Attachment attachment1 = new Attachment(
            name = 'Hello World 1.txt',
            body = Blob.valueOf('Hello World 1'),
            parentId = acct1.id
        );

        insert attachment1;

        Test.startTest();

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions( settings );

        ConvertAttachmentsToFilesQueueable queueable = new ConvertAttachmentsToFilesQueueable(
            new Set<ID>{ attachment1.id }
        );

        queueable.mockException = new System.NullPointerException();

        System.enqueueJob( queueable );

        Test.stopTest();

        for ( Convert_Attachments_to_Files_Log__c log : [ SELECT Status__c, Old_Attachment_ID__c, New_File_ID__c, Summary__c, Detail__c FROM Convert_Attachments_to_Files_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 0, [ SELECT count() FROM ContentVersion WHERE original_record_id__c = :attachment1.id ] );
        System.assertEquals( 0, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct1.id ] );
        System.assertEquals( 1, [ SELECT count() FROM Convert_Attachments_to_Files_Log__c WHERE status__c = 'ERROR' ] );

    }

}