/**
 * Developed by Doug Ayers (douglascayers.com)
 */
@isTest
private class ConvertAttachmentsToFilesServiceTest {

    @isTest
    static void test_special_characters() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;

        upsert settings;

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account account = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert account;

        Attachment plainAttachment = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf( 'Goodnight Moon' ),
            parentId = account.id,
            ownerId = user1.id
        );

        Attachment specialTitleAttachment = new Attachment(
            name = 'Hello ! @ # $ % ^ & * ( )  + = - _ \' \" , . ? / \\ [ ] { } | ` ~ < >',
            body = Blob.valueOf( 'Goodnight Moon' ),
            parentId = account.id,
            ownerId = user1.id
        );

        Attachment specialBodyAttachment = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf( 'Hello ! @ # $ % ^ & * ( )  + = - _ \' \" , . ? / \\ [ ] { } | ` ~ < >' ),
            parentId = account.id,
            ownerId = user1.id
        );

        Attachment specialTitleAndBodyAttachment = new Attachment(
            name = 'Hello ! @ # $ % ^ & * ( )  + = - _ \' \" , . ? / \\ [ ] { } | ` ~ < >',
            body = Blob.valueOf( 'Hello ! @ # $ % ^ & * ( )  + = - _ \' \" , . ? / \\ [ ] { } | ` ~ < >' ),
            parentId = account.id,
            ownerId = user1.id
        );

        Attachment htmlBodyAttachment = new Attachment(
            name = 'Hello World.html',
            body = Blob.valueOf( '<b>bold</b> <u>underline</u> <i>italic</i> <ul><li>list item</li></ul> <ol><li>list item</li></ol> <a href="www.salesforce.com">link</a> <div></div> <p></p> &nbsp; <span style="color:red">text</span> <img src="image.png"/>' ),
            parentId = account.id,
            ownerId = user1.id
        );

        Attachment githubIssue8 = new Attachment(
            name = 'Meeting Agenda 2016-06-16 agenda.pdf',
            body = Blob.valueOf( 'Meeting Agenda 2016-06-16 agenda.pdf' ),
            parentId = account.id,
            ownerId = user1.id
        );

        Attachment[] attachments = new Attachment[] { plainAttachment, specialTitleAttachment, specialBodyAttachment, specialTitleAndBodyAttachment, htmlBodyAttachment, githubIssue8 };

        // ensure user1 owns the records
        System.runAs( user1 ) {
            insert attachments;
        }

        attachments = [
            SELECT
                id, parentId, ownerId, name, description, body, isPrivate,
                createdById, createdDate, lastModifiedById, lastModifiedDate
            FROM
                Attachment
            WHERE
                id IN :attachments
        ];

        Test.startTest();

        List<ConvertAttachmentsToFilesService.ConversionResult> results = null;

        System.runAs( user1 ) {

            ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService();

            results = service.convert( attachments );

        }

        Test.stopTest();

        System.assertNotEquals( null, results );

        for ( ConvertAttachmentsToFilesService.ConversionResult result : results ) {
            System.debug( result );
            System.assertEquals( ConvertAttachmentsToFilesService.ConversionResultStatus.CONVERTED, result.status, result.message );
        }

    }

    @isTest
    static void test_fail_convert_0size_attachment() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = false;

        upsert settings;

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account account = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert account;

        Attachment attachment = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf(''), // can't set null, but can set zero-length string
            parentId = account.id,
            ownerId = user1.id
        );

        insert attachment;

        attachment = [
            SELECT
                id, parentId, ownerId, name, description, body, isPrivate,
                createdById, createdDate, lastModifiedById, lastModifiedDate,
                bodyLength
            FROM
                Attachment
            WHERE
                id = :attachment.id
        ];

        System.assertEquals( 0, attachment.bodyLength );

        Test.startTest();

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService();

        List<ConvertAttachmentsToFilesService.ConversionResult> results = service.convert( new Attachment[]{ attachment } );

        Test.stopTest();

        System.assertNotEquals( null, results );

        for ( ConvertAttachmentsToFilesService.ConversionResult result : results ) {
            System.debug( result );
            System.assertEquals( ConvertAttachmentsToFilesService.ConversionResultStatus.ERROR, result.status, result.message );
        }

        System.runAs( user1 ) {

            System.assertEquals( 0, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :account.id ] );
            System.assertEquals( 1, [ SELECT count() FROM Attachment WHERE id = :attachment.id ] );

        }

    }

    @isTest
    static void test_no_delete() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = false;

        upsert settings;

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account account = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert account;

        Attachment attachment = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf('Hello World'),
            parentId = account.id,
            ownerId = user1.id
        );

        insert attachment;

        attachment = [
            SELECT
                id, parentId, ownerId, name, description, body, isPrivate,
                createdById, createdDate, lastModifiedById, lastModifiedDate
            FROM
                Attachment
            WHERE
                id = :attachment.id
        ];

        Test.startTest();

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService();

        List<ConvertAttachmentsToFilesService.ConversionResult> results = service.convert( new Attachment[]{ attachment } );

        Test.stopTest();

        System.assertNotEquals( null, results );

        for ( ConvertAttachmentsToFilesService.ConversionResult result : results ) {
            System.debug( result );
            System.assertEquals( ConvertAttachmentsToFilesService.ConversionResultStatus.CONVERTED, result.status, result.message );
        }

        System.runAs( user1 ) {

            ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :attachment.id AND isLatest = true ];
            System.assert( cv != null );

            ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
            System.assert( cdl != null );

            List<Attachment> attachments = new List<Attachment>( [ SELECT id FROM Attachment WHERE id = :attachment.id ] );
            System.assertEquals( 1, attachments.size() );

        }

    }

    @isTest
    static void test_yes_delete() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;

        upsert settings;

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account account = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert account;

        Attachment attachment = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf('Hello World'),
            parentId = account.id,
            ownerId = user1.id
        );

        insert attachment;

        attachment = [
            SELECT
                id, parentId, ownerId, name, description, body, isPrivate,
                createdById, createdDate, lastModifiedById, lastModifiedDate
            FROM
                Attachment
            WHERE
                id = :attachment.id
        ];

        Test.startTest();

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions( settings );
        options.deleteAttachmentsUponConversion = true;

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService( options );

        List<ConvertAttachmentsToFilesService.ConversionResult> results = service.convert( new Attachment[]{ attachment } );

        Test.stopTest();

        System.assertNotEquals( null, results );

        for ( ConvertAttachmentsToFilesService.ConversionResult result : results ) {
            System.debug( result );
            System.assertEquals( ConvertAttachmentsToFilesService.ConversionResultStatus.CONVERTED, result.status, result.message );
        }

        System.runAs( user1 ) {

            ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :attachment.id AND isLatest = true ];
            System.assert( cv != null );

            ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
            System.assert( cdl != null );

            List<Attachment> attachments = new List<Attachment>( [ SELECT id FROM Attachment WHERE id = :attachment.id ] );
            System.assertEquals( 0, attachments.size() );

        }

    }

    @isTest
    static void test_no_share_private_attachments_with_parent_record() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = false;

        upsert settings;

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account account = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert account;

        Attachment attachment = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf('Hello World'),
            parentId = account.id,
            ownerId = user1.id,
            isPrivate = true
        );

        insert attachment;

        attachment = [
            SELECT
                id, parentId, ownerId, name, description, body, isPrivate,
                createdById, createdDate, lastModifiedById, lastModifiedDate
            FROM
                Attachment
            WHERE
                id = :attachment.id
        ];

        Test.startTest();

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions();

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService( options );

        List<ConvertAttachmentsToFilesService.ConversionResult> results = service.convert( new Attachment[]{ attachment } );

        Test.stopTest();

        System.runAs( user1 ) {

            System.assertNotEquals( null, results );

            for ( ConvertAttachmentsToFilesService.ConversionResult result : results ) {
                System.debug( result );
                System.assertEquals( ConvertAttachmentsToFilesService.ConversionResultStatus.CONVERTED, result.status, result.message );
            }

            ContentVersion cv = [ SELECT id, contentDocumentId, sharingPrivacy FROM ContentVersion WHERE original_record_id__c = :attachment.id AND isLatest = true ];
            System.assert( cv != null );
            System.assertEquals( 'P', cv.sharingPrivacy );

            ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
            System.assert( cdl != null );

            UserRecordAccess user2access = [ SELECT recordId, hasReadAccess FROM UserRecordAccess WHERE userId = :user2.id AND recordId = :cv.id ];
            System.assertEquals( false, user2access.hasReadAccess, 'not attachment owner should not see private attachment' );

        }

    }

    @isTest
    static void test_yes_share_private_attachments_with_parent_record() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;

        upsert settings;

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account account = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert account;

        Attachment attachment = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf('Hello World'),
            parentId = account.id,
            ownerId = user1.id,
            isPrivate = true
        );

        insert attachment;

        attachment = [
            SELECT
                id, parentId, ownerId, name, description, body, isPrivate,
                createdById, createdDate, lastModifiedById, lastModifiedDate
            FROM
                Attachment
            WHERE
                id = :attachment.id
        ];

        Test.startTest();

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions();

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService( options );

        List<ConvertAttachmentsToFilesService.ConversionResult> results = service.convert( new Attachment[]{ attachment } );

        Test.stopTest();

        System.runAs( user1 ) {

            System.assertNotEquals( null, results );

            for ( ConvertAttachmentsToFilesService.ConversionResult result : results ) {
                System.debug( result );
                System.assertEquals( ConvertAttachmentsToFilesService.ConversionResultStatus.CONVERTED, result.status, result.message );
            }

            ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :attachment.id AND isLatest = true ];
            System.assert( cv != null );

            ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
            System.assert( cdl != null );

        }

    }

    @isTest
    static void test_no_duplicates() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = false;

        upsert settings;

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = ConvertAttachmentsToFilesTestFactory.newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account account = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert account;

        Attachment attachment = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf('Hello World'),
            parentId = account.id,
            ownerId = user1.id
        );

        // new file owner is based on attachment's creator
        System.runAs( user1 ) {

            insert attachment;

        }

        attachment = [
            SELECT
                id, parentId, ownerId, name, description, body, isPrivate,
                createdById, createdDate, lastModifiedById, lastModifiedDate
            FROM
                Attachment
            WHERE
                id = :attachment.id
        ];

        Test.startTest();

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions();

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService( options );

        List<ConvertAttachmentsToFilesService.ConversionResult> results = service.convert( new Attachment[] { attachment } );

        for ( ConvertAttachmentsToFilesService.ConversionResult result : results ) {
            System.debug( result );
            System.assertEquals( ConvertAttachmentsToFilesService.ConversionResultStatus.CONVERTED, result.status, result.message );
        }

        System.assertEquals( 1, results.size() );
        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE contentDocument.latestPublishedVersion.original_record_id__c = :attachment.id AND linkedEntityId = :account.id ] );
        System.assertEquals( 1, [ SELECT count() FROM Attachment WHERE id = :attachment.id ] );

        // convert again, expect no duplicate file created

        results = service.convert( new Attachment[]{ attachment } );

        for ( ConvertAttachmentsToFilesService.ConversionResult result : results ) {
            System.debug( result );
            System.assertEquals( ConvertAttachmentsToFilesService.ConversionResultStatus.SKIPPED, result.status, result.message );
        }

        System.assertEquals( 1, results.size() );
        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE contentDocument.latestPublishedVersion.original_record_id__c = :attachment.id AND linkedEntityId = :account.id ] );
        System.assertEquals( 1, [ SELECT count() FROM Attachment WHERE id = :attachment.id ] );

        Test.stopTest();

    }

    @isTest
    static void test_init_options_from_settings() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = false;

        upsert settings;

        Test.startTest();

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions( settings );

        Test.stopTest();

        System.assertEquals( settings.Delete_Attachment_Once_Converted__c, options.deleteAttachmentsUponConversion );

    }

}