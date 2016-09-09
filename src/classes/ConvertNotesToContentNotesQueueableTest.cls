@isTest
private class ConvertNotesToContentNotesQueueableTest {

    @isTest
    static void test_queueable_with_options() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getInstance();
        settings.Convert_If_Feed_Tracking_Disabled__c = true;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Share_Private_Notes__c = true;
        settings.Conversion_Result_Email_Notifications__c = 'test@example.com';

        upsert settings;

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

        ConvertNotesToContentNotesQueueable queueable = new ConvertNotesToContentNotesQueueable(
            new Set<ID>{ note.id },
            new ConvertNotesToContentNotesOptions( settings )
        );

        System.enqueueJob( queueable );

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
    static void test_queueable_without_options() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getInstance();
        settings.Convert_If_Feed_Tracking_Disabled__c = true;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Share_Private_Notes__c = true;
        settings.Conversion_Result_Email_Notifications__c = 'test@example.com';

        upsert settings;

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

        ConvertNotesToContentNotesQueueable queueable = new ConvertNotesToContentNotesQueueable(
            new Set<ID>{ note.id }
        );

        System.enqueueJob( queueable );

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