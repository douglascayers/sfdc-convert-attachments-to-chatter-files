/**
 * Test class assumes Chatter Feed Tracking is enabled for Account object.
 */
@isTest
private class ConvertNotesToContentNotesServiceTest {

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

        Note note = new Note(
            title = 'Hello World.txt',
            body = 'Goodnight Moon',
            parentId = account.id,
            ownerId = user1.id
        );

        insert note;

        Test.startTest();

        ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService();

        service.convert( new Note[]{ note } );

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :note.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

        ContentNote cn = [ SELECT id, latestPublishedVersionId FROM ContentNote WHERE latestPublishedVersionId = :cv.id ];
        System.assert( cn != null );

        List<Note> notes = new List<Note>([ SELECT id FROM Note WHERE id = :note.id ]);
        System.assertEquals( 1, notes.size() );

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

        Note note = new Note(
            title = 'Hello World.txt',
            body = 'Goodnight Moon',
            parentId = account.id,
            ownerId = user1.id
        );

        insert note;

        Test.startTest();

        ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions();
        options.deleteNotesUponConversion = true;
        options.conversionResultEmailNotificationAddresses = new String[] { 'test@example.com' };

        ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService( options );

        service.convert( new Note[]{ note } );

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :note.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

        ContentNote cn = [ SELECT id, latestPublishedVersionId FROM ContentNote WHERE latestPublishedVersionId = :cv.id ];
        System.assert( cn != null );

        List<Note> notes = new List<Note>([ SELECT id FROM Note WHERE id = :note.id ]);
        System.assertEquals( 0, notes.size() );

    }

    @isTest
    static void test_no_share_private_notes_with_parent_record() {

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

        Note note = new Note(
            title = 'Hello World.txt',
            body = 'Goodnight Moon',
            parentId = account.id,
            ownerId = user1.id,
            isPrivate = true
        );

        insert note;

        Test.startTest();

        ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions();
        options.sharePrivateNotesWithParentRecord = false;
        options.conversionResultEmailNotificationAddresses = new String[] { 'test@example.com' };

        ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService( options );

        service.convert( new Note[]{ note } );

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :note.id AND isLatest = true ];
        System.assert( cv != null );

        List<ContentDocumentLink> cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assertEquals( 0, cdl.size() );

    }

    @isTest
    static void test_yes_share_private_notes_with_parent_record() {

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

        Note note = new Note(
            title = 'Hello World.txt',
            body = 'Goodnight Moon',
            parentId = account.id,
            ownerId = user1.id,
            isPrivate = true
        );

        insert note;

        Test.startTest();

        ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions();
        options.sharePrivateNotesWithParentRecord = true;
        options.conversionResultEmailNotificationAddresses = new String[] { 'test@example.com' };

        ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService( options );

        service.convert( new Note[]{ note } );

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :note.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

    }

    @isTest
    static void test_email_service() {

        List<String> recipients = new List<String>{ 'test@example.org' };

        Account acct = new Account(
            name = 'Test Account'
        );

        insert acct;

        Note note = new Note(
            title = 'Test Note',
            body = 'Goodnight Moon',
            parentId = acct.id
        );

        insert note;

        ContentNote cn = new ContentNote(
            title = 'Test ContentNote',
            content = Blob.valueOf('Goodnight Moon')
        );

        insert cn;

        ConvertNotesToContentNotesService.ConversionResult result1 = new ConvertNotesToContentNotesService.ConversionResult();
        result1.success = true;
        result1.noteId = note.id;
        result1.contentNoteId = cn.id;

        ConvertNotesToContentNotesService.ConversionResult result2 = new ConvertNotesToContentNotesService.ConversionResult();
        result2.success = false;
        result2.noteId = note.id;
        result2.message = 'Error Message';

        List<ConvertNotesToContentNotesService.ConversionResult> results = new List<ConvertNotesToContentNotesService.ConversionResult>{
            result1,
            result2
        };

        Test.startTest();

        ConvertNotesToContentNotesEmailService.sendEmail( recipients, results );

        Test.stopTest();

    }

    @isTest
    static void test_init_options_from_settings() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getInstance();
        settings.Convert_If_Feed_Tracking_Disabled__c = true;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Share_Private_Notes__c = true;
        settings.Conversion_Result_Email_Notifications__c = 'test@example.com';

        Test.startTest();

        ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions( settings );

        Test.stopTest();

        System.assertEquals( settings.Convert_If_Feed_Tracking_Disabled__c, options.convertIfFeedTrackingDisabledOnParentObject );
        System.assertEquals( settings.Delete_Note_Once_Converted__c, options.deleteNotesUponConversion );
        System.assertEquals( settings.Share_Private_Notes__c, options.sharePrivateNotesWithParentRecord );
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