@isTest
private class ConvertAttachmentsToFilesBatchableTest {

    @isTest
    static void test_batch() {
        
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
        
        ContentVersion file = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_attachment_id__c = :attachment.id AND isLatest = true ];
        System.assert( file != null );
        
        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :file.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );
        
    }
    
}