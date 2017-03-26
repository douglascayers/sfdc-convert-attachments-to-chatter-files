/**
 * Developed by Doug Ayers (douglascayers.com)
 */
@isTest
private class ConvertAttachmentsToFilesServiceTest {

    /**
     * https://github.com/DouglasCAyers/sfdc-convert-attachments-to-chatter-files/issues/9
     */
    @isTest
    static void test_partner_community_users() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = true;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Share_Private_Attachments__c = true;

        upsert settings;

        UserRole r1 = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p1 = [ SELECT id FROM Profile WHERE name = 'Standard User' ];
        Profile p2 = [ SELECT id FROM Profile WHERE name = 'Partner Community User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p1.id, r1.id, 'Alpha', 'User 1', 'user_1@example.com' );

            insert user1;

        }

        Account acct = new Account(
            ownerId = user1.id,
            name = 'Community Account'
        );

        insert acct;

        Contact cont = new Contact(
            accountId = acct.id,
            firstName = 'Beta',
            lastName = 'User 2'
        );

        insert cont;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user2 = newUser( p2.id, null, 'Beta',  'User 2', 'user_2@example.com' );

            user2.contactId = cont.id;

            insert user2;

        }

        Test.startTest();

        System.runAs( user2 ) {

            Attachment attachment1 = new Attachment(
                name = 'Hello World.txt',
                body = Blob.valueOf( 'Goodnight Moon' ),
                parentId = acct.id,
                ownerId = user2.id
            );

            insert attachment1;

            Attachment attachment2 = new Attachment(
                name = 'Hello World.txt',
                body = Blob.valueOf( 'Goodnight Moon' ),
                parentId = cont.id,
                ownerId = user2.id
            );

            insert attachment2;

        }

        Test.stopTest();

        // must do assert after stopping test because of async code
        System.assertEquals( 2, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId IN ( :acct.id, :cont.id ) ] );

    }

    @isTest
    static void test_special_characters() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'InternalUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Share_Private_Attachments__c = true;

        upsert settings;

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

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
            body = Blob.valueOf( '<b>bold</b> <u>underline</u> <i>italic</i> <ul><li>list item</li></ul> <ol><li>list item</li></ol> <a href="www.salesforce.com">link</a> <div></div> <p></p> &nbsp;' ),
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
            System.assertEquals( true, result.success );
        }

    }

    @isTest
    static void test_no_delete() {

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

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

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions();
        options.deleteAttachmentsUponConversion = false;

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService( options );

        service.convert( new Attachment[] { attachment } );

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :attachment.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

        List<Attachment> attachments = new List<Attachment>([ SELECT id FROM Attachment WHERE id = :attachment.id ]);
        System.assertEquals( 1, attachments.size() );

    }

    @isTest
    static void test_yes_delete() {

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

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

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions();
        options.deleteAttachmentsUponConversion = true;

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService( options );

        service.convert( new Attachment[]{ attachment } );

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :attachment.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

        List<Attachment> attachments = new List<Attachment>([ SELECT id FROM Attachment WHERE id = :attachment.id ]);
        System.assertEquals( 0, attachments.size() );

    }

    @isTest
    static void test_no_share_private_attachments_with_parent_record() {

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

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
        options.sharePrivateAttachmentsWithParentRecord = false;

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService( options );

        service.convert( new Attachment[]{ attachment } );

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :attachment.id AND isLatest = true ];
        System.assert( cv != null );

        List<ContentDocumentLink> cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assertEquals( 0, cdl.size() );

    }

    @isTest
    static void test_yes_share_private_attachments_with_parent_record() {

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

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
        options.sharePrivateAttachmentsWithParentRecord = true;

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService( options );

        service.convert( new Attachment[] { attachment } );

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :attachment.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

    }

    @isTest
    static void test_init_options_from_settings() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'InternalUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Attachment_Once_Converted__c = false;
        settings.Share_Private_Attachments__c = true;

        upsert settings;

        Test.startTest();

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions( settings );

        Test.stopTest();

        System.assertEquals( settings.Share_Type__c, options.shareType );
        System.assertEquals( settings.Visibility__c, options.visibility );
        System.assertEquals( settings.Delete_Attachment_Once_Converted__c, options.deleteAttachmentsUponConversion );
        System.assertEquals( settings.Share_Private_Attachments__c, options.sharePrivateAttachmentsWithParentRecord );

    }

    private static User newUser( ID profileId, ID roleId, String firstName, String lastName, String email ) {
        Integer rand = Math.round( Math.random() * 1000 );
        return new User(
            isActive = true,
            profileId = profileId,
            userRoleId = roleId,
            alias = firstName.substring(0,1) + lastName.substring(1,5),
            firstName = firstName,
            lastName = lastName,
            email = email,
            username = rand + email,
            emailEncodingKey = 'UTF-8',
            languageLocaleKey = 'en_US',
            localeSidKey = 'en_US',
            timeZoneSidKey = 'America/Chicago'
        );
    }

}