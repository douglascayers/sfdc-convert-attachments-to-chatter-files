@isTest
private class ConvertAttachmentsToFilesBatchableTest {

    @isTest
    static void test_batch_no_delete() {

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

        ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable();
        batchable.deleteAttachmentsUponConversion = false;

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :attachment.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

        List<Attachment> attachments = new List<Attachment>([ SELECT id FROM Attachment WHERE id = :attachment.id ]);
        System.assertEquals( 1, attachments.size() );

    }

    @isTest
    static void test_batch_yes_delete() {

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

        ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable();
        batchable.deleteAttachmentsUponConversion = true;

        Database.executeBatch( batchable, 100 );

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

        ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable();
        batchable.sharePrivateAttachmentsWithParentRecord = false;

        Database.executeBatch( batchable, 100 );

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

        ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable();
        batchable.sharePrivateAttachmentsWithParentRecord = true;

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :attachment.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

    }

    @isTest
    static void test_scope_conversion() {

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account acct1 = new Account(
            ownerId = user1.id,
            name = 'Test Account 1'
        );

        insert acct1;

        Account acct2 = new Account(
            ownerId = user2.id,
            name = 'Test Account 2'
        );

        insert acct2;

        Attachment attachment1 = new Attachment(
            name = 'Hello World 1.txt',
            body = Blob.valueOf('Hello World 1'),
            parentId = acct1.id,
            ownerId = user1.id
        );

        insert attachment1;

        Attachment attachment2 = new Attachment(
            name = 'Hello World 2.txt',
            body = Blob.valueOf('Hello World 2'),
            parentId = acct2.id,
            ownerId = user2.id
        );

        insert attachment2;

        Test.startTest();

        ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable();
        batchable.parentIds = new Set<ID>{ acct1.id };

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        List<ContentVersion> cv = [ SELECT id, contentDocumentId, original_record_id__c FROM ContentVersion WHERE isLatest = true ];
        System.assertEquals( 1, cv.size() );
        System.assertEquals( attachment1.id, cv[0].original_record_id__c );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.get(0).contentDocumentId AND linkedEntityId = :acct1.id ];
        System.assert( cdl != null );

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
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert acct;

        Attachment attachment1 = new Attachment(
            name = 'Hello World 1.txt',
            body = Blob.valueOf('Hello World 1'),
            parentId = acct.id,
            ownerId = user1.id
        );

        insert attachment1;

        Attachment attachment2 = new Attachment(
            name = 'Hello World 2.txt',
            body = Blob.valueOf('Hello World 2'),
            parentId = acct.id,
            ownerId = user2.id
        );

        insert attachment2;

        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user2.isActive = false;
            update user2;

        }

        // at this point we have attachments:
        // one owned by an active user
        // one owned by an inactive user
        // after conversion the active user should own the new file
        // but the inactive user will not be related to the record

        Test.startTest();

        ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable();

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        List<ContentVersion> cv = [ SELECT id, contentDocumentId, original_record_id__c, original_record_parent_id__c, original_record_owner_id__c FROM ContentVersion WHERE isLatest = true ];
        System.assertEquals( 1, cv.size() );
        System.assertEquals( attachment1.id, cv[0].original_record_id__c );
        System.assertEquals( attachment1.parentId, cv[0].original_record_parent_id__c );
        System.assertEquals( attachment1.ownerId, cv[0].original_record_owner_id__c );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.get(0).contentDocumentId AND linkedEntityId = :acct.id ];
        System.assert( cdl != null );

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