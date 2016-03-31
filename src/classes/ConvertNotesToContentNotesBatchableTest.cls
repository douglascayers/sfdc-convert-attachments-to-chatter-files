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

        Database.executeBatch( new ConvertNotesToContentNotesBatchable(), 100 );

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

        Boolean deleteNotesUponConversion = true;
        Database.executeBatch( new ConvertNotesToContentNotesBatchable( deleteNotesUponConversion ), 100 );

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

}