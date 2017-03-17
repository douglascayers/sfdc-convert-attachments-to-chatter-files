@isTest
private class ConvertAttachmentsToFilesQueueableTest {

    @isTest
    static void test_queueable_with_options() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getInstance();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Share_Private_Attachments__c = true;

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

        Attachment attachment = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf('Hello World'),
            parentId = account.id,
            ownerId = user1.id
        );

        insert attachment;

        Test.startTest();

        ConvertAttachmentsToFilesQueueable queueable = new ConvertAttachmentsToFilesQueueable(
            new Set<ID>{ attachment.id },
            new ConvertAttachmentsToFilesOptions( settings )
        );

        System.enqueueJob( queueable );

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :attachment.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

        List<Attachment> attachments = new List<Attachment>([ SELECT id FROM Attachment WHERE id = :attachment.id ]);
        System.assertEquals( 0, attachments.size() );

    }

    @isTest
    static void test_queueable_without_options() {

        Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getInstance();
        settings.Delete_Attachment_Once_Converted__c = true;
        settings.Share_Private_Attachments__c = true;

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

        Attachment attachment = new Attachment(
            name = 'Hello World.txt',
            body = Blob.valueOf('Hello World'),
            parentId = account.id,
            ownerId = user1.id
        );

        insert attachment;

        Test.startTest();

        ConvertAttachmentsToFilesQueueable queueable = new ConvertAttachmentsToFilesQueueable(
            new Set<ID>{ attachment.id }
        );

        System.enqueueJob( queueable );

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :attachment.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

        List<Attachment> attachments = new List<Attachment>([ SELECT id FROM Attachment WHERE id = :attachment.id ]);
        System.assertEquals( 1, attachments.size() );

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