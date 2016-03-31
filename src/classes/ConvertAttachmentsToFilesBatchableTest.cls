@isTest
private class ConvertAttachmentsToFilesBatchableTest {

    @isTest
    static void test_batch_no_delete() {

        Account account = new Account(
            name = 'Test Account'
        );

        insert account;

        Attachment attachment = new Attachment(
            name = 'HelloWorld.txt',
            body = Blob.valueOf( 'Hello World.' ),
            parentId = account.id
        );

        insert attachment;

        Test.startTest();

        Database.executeBatch( new ConvertAttachmentsToFilesBatchable(), 200 );

        Test.stopTest();

        ContentVersion file = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :attachment.id AND isLatest = true ];
        System.assert( file != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :file.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

        List<Attachment> attachments = new List<Attachment>([ SELECT id FROM Attachment WHERE id = :attachment.id ]);
        System.assertEquals( 1, attachments.size() );

    }

    @isTest
    static void test_batch_yes_delete() {

        Account account = new Account(
            name = 'Test Account'
        );

        insert account;

        Attachment attachment = new Attachment(
            name = 'HelloWorld.txt',
            body = Blob.valueOf( 'Hello World.' ),
            parentId = account.id
        );

        insert attachment;

        Test.startTest();

        Boolean deleteAttachmentsUponConversion = true;
        Database.executeBatch( new ConvertAttachmentsToFilesBatchable( deleteAttachmentsUponConversion ), 200 );

        Test.stopTest();

        ContentVersion file = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :attachment.id AND isLatest = true ];
        System.assert( file != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :file.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

        List<Attachment> attachments = new List<Attachment>([ SELECT id FROM Attachment WHERE id = :attachment.id ]);
        System.assertEquals( 0, attachments.size() );

    }

}