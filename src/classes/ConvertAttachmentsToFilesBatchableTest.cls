/**
 * Developed by Doug Ayers (douglascayers.com)
 */
@isTest
private class ConvertAttachmentsToFilesBatchableTest {

    @isTest
    static void test_real_time_trigger() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = true;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Convert_Private_Attachments__c = true;
        settings.Share_Private_Attachments__c = true;

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
            name = 'Test Account',
            ownerId = user1.id
        );

        insert acct1;

        Attachment attachment1 = new Attachment(
            name = 'Hello World 1.txt',
            body = Blob.valueOf('Hello World 1'),
            parentId = acct1.id,
            ownerId = user1.id
        );

        Test.startTest();

        System.runAs( user1 ) {

            insert attachment1;

        }

        Test.stopTest();

        for ( Convert_Attachments_to_Files_Log__c log : [ SELECT Status__c, Old_Attachment_ID__c, New_File_ID__c, Summary__c, Detail__c FROM Convert_Attachments_to_Files_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct1.id ] );
        System.assertEquals( 0, [ SELECT count() FROM Attachment WHERE id = :attachment1.id ] );

        ContentDocumentLink cdl_file1 = [
            SELECT
                id,
                contentDocumentId,
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

        System.assertEquals( attachment1.id, cdl_file1.contentDocument.latestPublishedVersion.original_record_id__c );
        System.assertEquals( attachment1.parentId, cdl_file1.contentDocument.latestPublishedVersion.original_record_parent_id__c );
        System.assertEquals( attachment1.ownerId, cdl_file1.contentDocument.latestPublishedVersion.original_record_owner_id__c );

    }

    @isTest
    static void test_scope_conversion() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Convert_Private_Attachments__c = true;
        settings.Share_Private_Attachments__c = true;

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
            name = 'Test Account 1'
        );

        insert acct1;

        Account acct2 = new Account(
            ownerId = user2.id,
            name = 'Test Account 2'
        );

        insert acct2;

        Attachment attachment1 = new Attachment(
            name = 'Hello World 1.txt',
            body = Blob.valueOf('Hello World 1'),
            parentId = acct1.id,
            ownerId = user1.id
        );

        insert attachment1;

        Attachment attachment2 = new Attachment(
            name = 'Hello World 2.txt',
            body = Blob.valueOf('Hello World 2'),
            parentId = acct2.id,
            ownerId = user2.id
        );

        insert attachment2;

        Test.startTest();

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions( settings );
        options.parentIds = new Set<ID>{ acct1.id };

        ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable( options );

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        for ( Convert_Attachments_to_Files_Log__c log : [ SELECT Status__c, Old_Attachment_ID__c, New_File_ID__c, Summary__c, Detail__c FROM Convert_Attachments_to_Files_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct1.id ] );
        System.assertEquals( 0, [ SELECT count() FROM Attachment WHERE id = :attachment1.id ] );

        System.assertEquals( 0, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct2.id ] );
        System.assertEquals( 1, [ SELECT count() FROM Attachment WHERE id = :attachment2.id ] );

        ContentDocumentLink cdl_file1 = [
            SELECT
                id,
                contentDocumentId,
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

        System.assertEquals( attachment1.id, cdl_file1.contentDocument.latestPublishedVersion.original_record_id__c );
        System.assertEquals( attachment1.parentId, cdl_file1.contentDocument.latestPublishedVersion.original_record_parent_id__c );
        System.assertEquals( attachment1.ownerId, cdl_file1.contentDocument.latestPublishedVersion.original_record_owner_id__c );

    }

    @isTest
    static void test_preserve_original_owner() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Convert_Private_Attachments__c = true;
        settings.Share_Private_Attachments__c = true;

        upsert settings;

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account acct = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert acct;

        Attachment attachment1 = new Attachment(
            name = 'Hello World 1.txt',
            body = Blob.valueOf('Hello World 1'),
            parentId = acct.id,
            ownerId = user1.id
        );

        insert attachment1;

        Attachment attachment2 = new Attachment(
            name = 'Hello World 2.txt',
            body = Blob.valueOf('Hello World 2'),
            parentId = acct.id,
            ownerId = user2.id
        );

        insert attachment2;

        Test.startTest();

        ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable();

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        for ( Convert_Attachments_to_Files_Log__c log : [ SELECT Status__c, Old_Attachment_ID__c, New_File_ID__c, Summary__c, Detail__c FROM Convert_Attachments_to_Files_Log__c ] ) {
            System.debug( log );
        }

        ContentDocumentLink cdl_file1 = [
            SELECT
                id,
                contentDocument.fileType,
                contentDocumentId,
                contentDocument.latestPublishedVersion.original_record_id__c,
                contentDocument.latestPublishedVersion.original_record_parent_id__c,
                contentDocument.latestPublishedVersion.original_record_owner_id__c
            FROM
                ContentDocumentLink
            WHERE
            linkedEntityId = :acct.id
            AND
            contentDocument.latestPublishedVersion.original_record_id__c = :attachment1.id
        ];

        System.assertEquals( 'TEXT', cdl_file1.contentDocument.fileType );
        System.assertEquals( attachment1.id, cdl_file1.contentDocument.latestPublishedVersion.original_record_id__c );
        System.assertEquals( attachment1.parentId, cdl_file1.contentDocument.latestPublishedVersion.original_record_parent_id__c );
        System.assertEquals( attachment1.ownerId, cdl_file1.contentDocument.latestPublishedVersion.original_record_owner_id__c );

        ContentDocumentLink cdl_file2 = [
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
            linkedEntityId = :acct.id
            AND
            contentDocument.latestPublishedVersion.original_record_id__c = :attachment2.id
        ];

        System.assertEquals( 'TEXT', cdl_file2.contentDocument.fileType );
        System.assertEquals( attachment2.id, cdl_file2.contentDocument.latestPublishedVersion.original_record_id__c );
        System.assertEquals( attachment2.parentId, cdl_file2.contentDocument.latestPublishedVersion.original_record_parent_id__c );
        System.assertEquals( attachment2.ownerId, cdl_file2.contentDocument.latestPublishedVersion.original_record_owner_id__c );

    }

    @isTest
    static void test_preserve_original_inactive_owner() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Convert_Private_Attachments__c = true;
        settings.Share_Private_Attachments__c = true;

        upsert settings;

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account acct = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert acct;

        System.runAs( user1 ) {

            Attachment attachment1 = new Attachment(
                name = 'Hello World 1.txt',
                body = Blob.valueOf('Hello World 1'),
                parentId = acct.id,
                ownerId = user1.id
            );

            insert attachment1;

        }

        System.runAs( user2 ) {

            Attachment attachment2 = new Attachment(
                name = 'Hello World 2.txt',
                body = Blob.valueOf('Hello World 2'),
                parentId = acct.id,
                ownerId = user2.id
            );

            insert attachment2;

        }

        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user2.isActive = false;
            update user2;

        }

        Test.startTest();

        ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable();

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        for ( Convert_Attachments_to_Files_Log__c log : [ SELECT Status__c, Old_Attachment_ID__c, New_File_ID__c, Summary__c, Detail__c FROM Convert_Attachments_to_Files_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 2, [ SELECT count() FROM Convert_Attachments_to_Files_Log__c ] );
        System.assertEquals( 2, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct.id ] );
        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct.id AND contentDocument.ownerId = :user1.id ] );
        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct.id AND contentDocument.ownerId = :user2.id ] );
        System.assertEquals( 0, [ SELECT count() FROM Attachment ] );

    }

    @isTest
    static void test_conversion_error() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Convert_Private_Attachments__c = true;
        settings.Share_Private_Attachments__c = true;

        upsert settings;

        EmailMessage msg = new EmailMessage(
            subject = 'Test Email'
        );

        insert msg;

        Attachment attachment = new Attachment(
            name = 'Hello World 1.txt',
            body = Blob.valueOf('Hello World 1'),
            parentId = msg.id
        );

        insert attachment;

        Test.startTest();

        ConvertAttachmentsToFilesService.ConversionResult mockResult = new ConvertAttachmentsToFilesService.ConversionResult();
        mockResult.status = ConvertAttachmentsToFilesService.ConversionResultStatus.ERROR;
        mockResult.message = 'Mock Error Result';

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions( settings );

        ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable( options );

        batchable.mockResults = new List<ConvertAttachmentsToFilesService.ConversionResult>{ mockResult };

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        for ( Convert_Attachments_to_Files_Log__c log : [ SELECT Status__c, Old_Attachment_ID__c, New_File_ID__c, Summary__c, Detail__c FROM Convert_Attachments_to_Files_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 1, [ SELECT count() FROM Convert_Attachments_to_Files_Log__c WHERE Status__c = 'ERROR' ] );

    }

    @isTest
    static void test_conversion_exception() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Convert_Private_Attachments__c = true;
        settings.Share_Private_Attachments__c = true;

        upsert settings;

        Account acct = new Account(
            name = 'Test Account'
        );

        insert acct;

        Attachment attachment = new Attachment(
            name = 'Hello World 1.txt',
            body = Blob.valueOf('Hello World 1'),
            parentId = acct.id
        );

        insert attachment;

        Test.startTest();

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions( settings );

        ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable( options );

        batchable.mockException = new System.NullPointerException();

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        for ( Convert_Attachments_to_Files_Log__c log : [ SELECT Status__c, Old_Attachment_ID__c, New_File_ID__c, Summary__c, Detail__c FROM Convert_Attachments_to_Files_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 1, [ SELECT count() FROM Convert_Attachments_to_Files_Log__c WHERE Status__c = 'ERROR' ] );

    }

}