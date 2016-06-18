@isTest
private class ConvertNotesToContentNotesBatchableTest {

    @isTest
    static void test_batch_no_delete() {

        Account account = new Account(
            name = 'Test Account'
        );

        insert account;

        Note note = new Note(
            title = 'Test Title',
            body = 'Test Body',
            parentId = account.id
        );

        insert note;

        Test.startTest();

        ConvertNotesToContentNotesBatchable batchable = new ConvertNotesToContentNotesBatchable();

        Database.executeBatch( batchable, 100 );

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
    static void test_batch_yes_delete() {

        Account account = new Account(
            name = 'Test Account'
        );

        insert account;

        Note note = new Note(
            title = 'Test Title',
            body = 'Test Body',
            parentId = account.id
        );

        insert note;

        Test.startTest();

        ConvertNotesToContentNotesBatchable batchable = new ConvertNotesToContentNotesBatchable();
        batchable.deleteNotesUponConversion = true;

        Database.executeBatch( batchable, 100 );

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

        Account account = new Account(
            name = 'Test Account'
        );

        insert account;

        Note note = new Note(
            title = 'Test Title',
            body = 'Test Body',
            parentId = account.id,
            isPrivate = true
        );

        insert note;

        Test.startTest();

        ConvertNotesToContentNotesBatchable batchable = new ConvertNotesToContentNotesBatchable();
        batchable.sharePrivateNotesWithParentRecord = false;

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :note.id AND isLatest = true ];
        System.assert( cv != null );

        List<ContentDocumentLink> cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assertEquals( 0, cdl.size() );

        ContentNote cn = [ SELECT id, latestPublishedVersionId FROM ContentNote WHERE latestPublishedVersionId = :cv.id ];
        System.assert( cn != null );

    }

    @isTest
    static void test_yes_share_private_notes_with_parent_record() {

        Account account = new Account(
            name = 'Test Account'
        );

        insert account;

        Note note = new Note(
            title = 'Test Title',
            body = 'Test Body',
            parentId = account.id,
            isPrivate = true
        );

        insert note;

        Test.startTest();

        ConvertNotesToContentNotesBatchable batchable = new ConvertNotesToContentNotesBatchable();
        batchable.sharePrivateNotesWithParentRecord = true;

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :note.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

        ContentNote cn = [ SELECT id, latestPublishedVersionId FROM ContentNote WHERE latestPublishedVersionId = :cv.id ];
        System.assert( cn != null );

    }

    @isTest
    static void test_scope_conversion() {

        Account acct1 = new Account(
            name = 'Test Account 1'
        );

        insert acct1;

        Account acct2 = new Account(
            name = 'Test Account 2'
        );

        insert acct2;

        Note note1 = new Note(
            title = 'Test Title 1',
            body = 'Test Body 1',
            parentId = acct1.id
        );

        insert note1;

        Note note2 = new Note(
            title = 'Test Title 2',
            body = 'Test Body 2',
            parentId = acct2.id
        );

        insert note2;

        Test.startTest();

        ConvertNotesToContentNotesBatchable batchable = new ConvertNotesToContentNotesBatchable();
        batchable.parentIds = new Set<ID>{ acct1.id };

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        List<ContentVersion> cv = [ SELECT id, contentDocumentId, original_record_id__c FROM ContentVersion WHERE isLatest = true ];
        System.assertEquals( 1, cv.size() );
        System.assertEquals( note1.id, cv[0].original_record_id__c );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.get(0).contentDocumentId AND linkedEntityId = :acct1.id ];
        System.assert( cdl != null );

        ContentNote cn = [ SELECT id, latestPublishedVersionId FROM ContentNote WHERE latestPublishedVersionId = :cv.get(0).id ];
        System.assert( cn != null );

    }

    @isTest
    static void test_preserve_original_owner() {

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account acct = new Account(
            name = 'Test Account'
        );

        insert acct;

        Note note1, note2;

        note1 = new Note(
            ownerId = user1.id,
            title = 'Note 1',
            parentId = acct.id
        );

        note2 = new Note(
            ownerId = user2.id,
            title = 'Note 2',
            parentId = acct.id
        );

        insert new List<Note>{ note1, note2 };

        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user2.isActive = false;
            update user2;

        }

        // at this point we have notes:
        // one owned by an active user
        // one owned by an inactive user
        // after conversion the active user should own the new note
        // but the inactive user will not be related to the record

        Test.startTest();

        ConvertNotesToContentNotesBatchable batchable = new ConvertNotesToContentNotesBatchable();

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        List<ContentVersion> cv = [ SELECT id, contentDocumentId, original_record_id__c, original_record_parent_id__c, original_record_owner_id__c FROM ContentVersion WHERE isLatest = true ];
        System.assertEquals( 1, cv.size() );
        System.assertEquals( note1.id, cv[0].original_record_id__c );
        System.assertEquals( note1.parentId, cv[0].original_record_parent_id__c );
        System.assertEquals( note1.ownerId, cv[0].original_record_owner_id__c );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.get(0).contentDocumentId AND linkedEntityId = :acct.id ];
        System.assert( cdl != null );

        ContentNote cn = [ SELECT id, latestPublishedVersionId FROM ContentNote WHERE latestPublishedVersionId = :cv.get(0).id ];
        System.assert( cn != null );

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