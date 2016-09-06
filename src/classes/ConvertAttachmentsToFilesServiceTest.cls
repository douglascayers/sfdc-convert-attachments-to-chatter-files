/**
 * Test class assumes Chatter Feed Tracking is enabled for Account object.
 */
@isTest
private class ConvertAttachmentsToFilesServiceTest {

    @isTest
    static void test_no_delete() {

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, 'Beta',  'User 2', 'user_2@example.com' );

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

        Test.startTest();

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService();

        service.convert( new Attachment[]{ attachment } );

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

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, 'Beta',  'User 2', 'user_2@example.com' );

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

        Test.startTest();

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions();
        options.deleteAttachmentsUponConversion = true;
        options.conversionResultEmailNotificationAddresses = new String[] { 'test@example.com' };

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

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, 'Beta',  'User 2', 'user_2@example.com' );

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

        Test.startTest();

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions();
        options.sharePrivateAttachmentsWithParentRecord = false;
        options.conversionResultEmailNotificationAddresses = new String[] { 'test@example.com' };

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

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, 'Beta',  'User 2', 'user_2@example.com' );

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

        Test.startTest();

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions();
        options.sharePrivateAttachmentsWithParentRecord = true;
        options.conversionResultEmailNotificationAddresses = new String[] { 'test@example.com' };

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService( options );

        service.convert( new Attachment[]{ attachment } );

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :attachment.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

    }

    @isTest
    static void test_inbound_email_and_do_convert() {

        Case cs = new Case(
            subject = 'Test'
        );

        insert cs;

        EmailMessage message1 = new EmailMessage(
            parentId = cs.id,
            incoming = true,
            fromAddress = 'test@example.org',
            toAddress = 'user@example.org',
            subject = 'Test Email'
        );

        insert message1;

        EmailMessage message2 = new EmailMessage(
            parentId = cs.id,
            incoming = false,
            fromAddress = 'test@example.org',
            toAddress = 'user@example.org',
            subject = 'Test Email'
        );

        insert message2;

        Attachment attachment1 = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf('Hello World'),
            parentId = message1.id
        );

        insert attachment1;

        Attachment attachment2 = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf('Hello World'),
            parentId = message2.id
        );

        insert attachment2;

        Test.startTest();

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions();
        options.conversionResultEmailNotificationAddresses = new String[] { 'test@example.com' };
        options.convertInboundEmailMessageAttachmentsToFilesOnCases = true;
        options.convertIfFeedTrackingDisabledOnParentObject = true;

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService( options );

        List<ConvertAttachmentsToFilesService.ConversionResult> results = service.convert([
            SELECT
                id, ownerId, owner.isActive, parentId, name, description, body, isPrivate
            FROM
                Attachment
        ]);

        Test.stopTest();

        System.debug( results );

        for ( ConvertAttachmentsToFilesService.ConversionResult result : results ) {
            if ( result.attachmentId == attachment1.id ) {
                System.assertEquals( true, result.success );
                System.assert( String.isBlank( result.message ) );
            } else if ( result.attachmentId == attachment2.id ) {
                System.assertEquals( true, result.success );
                System.assert( String.isNotBlank( result.message ) );
            }
        }

        ConvertAttachmentsToFilesEmailService.sendEmail( new String[] { 'test@example.com' }, results );

    }

    @isTest
    static void test_inbound_email_and_do_not_convert() {

        Case cs = new Case(
            subject = 'Test'
        );

        insert cs;

        EmailMessage message1 = new EmailMessage(
            parentId = cs.id,
            incoming = true,
            fromAddress = 'test@example.org',
            toAddress = 'user@example.org',
            subject = 'Test Email'
        );

        insert message1;

        EmailMessage message2 = new EmailMessage(
            parentId = cs.id,
            incoming = false,
            fromAddress = 'test@example.org',
            toAddress = 'user@example.org',
            subject = 'Test Email'
        );

        insert message2;

        Attachment attachment1 = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf('Hello World'),
            parentId = message1.id
        );

        insert attachment1;

        Attachment attachment2 = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf('Hello World'),
            parentId = message2.id
        );

        insert attachment2;

        Test.startTest();

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions();
        options.conversionResultEmailNotificationAddresses = new String[] { 'test@example.com' };
        options.convertInboundEmailMessageAttachmentsToFilesOnCases = true;
        options.convertIfFeedTrackingDisabledOnParentObject = false;

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService( options );

        List<ConvertAttachmentsToFilesService.ConversionResult> results = service.convert([
            SELECT
                id, ownerId, owner.isActive, parentId, name, description, body, isPrivate
            FROM
                Attachment
        ]);

        Test.stopTest();

        System.debug( results );

        for ( ConvertAttachmentsToFilesService.ConversionResult result : results ) {
            if ( result.attachmentId == attachment1.id ) {
                System.assertEquals( true, result.success );
                System.assert( String.isBlank( result.message ) );
            } else if ( result.attachmentId == attachment2.id ) {
                System.assertEquals( false, result.success );
                System.assert( String.isNotBlank( result.message ) );
            }
        }

        ConvertAttachmentsToFilesEmailService.sendEmail( new String[] { 'test@example.com' }, results );

    }

    @isTest
    static void test_init_options_from_settings() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getInstance();
        settings.Convert_If_Feed_Tracking_Disabled__c = true;
        settings.Convert_Inbound_Email_Attachments__c = true;
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Share_Private_Attachments__c = true;
        settings.Conversion_Result_Email_Notifications__c = 'test@example.com';

        Test.startTest();

        ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions( settings );

        Test.stopTest();

        System.assertEquals( settings.Convert_If_Feed_Tracking_Disabled__c, options.convertIfFeedTrackingDisabledOnParentObject );
        System.assertEquals( settings.Convert_Inbound_Email_Attachments__c, options.convertInboundEmailMessageAttachmentsToFilesOnCases );
        System.assertEquals( settings.Delete_Attachment_Once_Converted__c, options.deleteAttachmentsUponConversion );
        System.assertEquals( settings.Share_Private_Attachments__c, options.sharePrivateAttachmentsWithParentRecord );
        System.assertEquals( settings.Conversion_Result_Email_Notifications__c, options.conversionResultEmailNotificationAddresses[0] );

    }

    private static User newUser( ID profileId, String firstName, String lastName, String email ) {
        Integer rand = Math.round( Math.random() * 1000 );
        return new User(
            isActive = true,
            profileId = profileId,
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