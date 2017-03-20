Convert Attachments to Chatter Files
====================================

Overview
--------

This project contains multiple apex classes (triggers, queueables, batchables, schedulables) to assist with the manual or automatic conversion of
classic [Attachments](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_attachment.htm)
into [Chatter Files](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_contentversion.htm)
to take advantage of rich-text, and more sophisticated sharing and file revisions.
You may like to read my [blog post](https://douglascayers.wordpress.com/2015/10/10/salesforce-convert-attachments-to-chatter-files/) on the topic.


Installation
------------

* [Deploy from Github](https://githubsfdeploy.herokuapp.com)


Usage
-----

There are three main ways to perform the conversions:

1. **Manually** invoke a batchable class for a one-time conversion of attachments
2. **Schedule** a batchable class for periodic conversions of attachments (e.g. hourly, daily, monthly)
3. **Near real-time** with trigger to convert attachments as they are inserted

When you choose either option **manually** or **scheduled** then you likely are kicking off the process using **Developer Console**.
You will want to configure some preferences with the `ConvertAttachmentsToFilesOptions` class
when you execute or schedule the batchable class `ConvertAttachmentsToFilesBatchable`.

When you choose option **near real-time** then you configure your preferences using **custom settings**.
This project includes one custom setting, **Convert Attachments to Files Settings**.
It is a hierarchical setting and you likely only need the default organization level values configured.
Please note, the settings you can toggle available to you are exactly the same regardless which option (1, 2, or 3) you choose.

|Attachment Settings                     |Description                                                                                      |
|----------------------------------------|-------------------------------------------------------------------------------------------------|
|Convert in Near Real Time?              |Enables trigger to convert attachments to files. Invokes queuable to process them asynchronously.|
|Share Private Attachments?              |If private attachment is converted, will share its access with the parent record or not.         |
|Delete Attachment Once Converted?       |Deletes attachment once converted. This can save storage space. Backup your data!                |
|Share Type                              |Controls view/edit access to the file. Use "V" for view only. Use "I" to infer by parent record. |
|Visibility                              |Controls community access. Can be "InternalUsers" or "AllUsers". For communities, use "AllUsers".|

To learn more about `Share Type` and `Visibility` please refer to [ContentDocumentLink](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_contentdocumentlink.htm) documentation.


Examples
--------

*Manually Invoke Batchable Class*

    // default options per custom setting
    Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getInstance();
    ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions( settings );

    // or, explicitly set options for this run
    ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions();
    options.deleteAttachmentsUponConversion = false;
    options.sharePrivateAttachmentsWithParentRecord = false;
    options.shareType = 'V';
    options.visibility = 'InternalUsers';

    // then run batchable
    ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable( options );
    Database.executeBatch( batchable, 100 );

*Schedule Batachable Class*

    // default options per custom setting
    Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getInstance();
    ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions( settings );

    // or, explicitly set options for this run
    ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions();
    options.deleteAttachmentsUponConversion = true;
    options.sharePrivateAttachmentsWithParentRecord = true;
    options.shareType = 'I';
    options.visibility = 'AllUsers';

    // then schedule job
    // note, to change options after job is scheduled you need to stop the job and kick it off again with new option selections
    Integer batchSize = 100;
    System.schedule( 'Convert Attachments to Files Job', '0 0 13 * * ?', new ConvertAttachmentsToFilesSchedulable( batchSize, options ) );

*Enable Trigger for Real-Time*

    In Setup, navigate to custom setting **Convert Attachments to Files Settings** and check "Convert in Near Real Time?" field.
    The apex trigger looks at this value to know whether to convert attachments or not when they are inserted.


Private Notes / Attachments
---------------------------
Classic Notes & Attachments have an 'IsPrivate' checkbox field that when selected
makes the record only visible to the owner and administrators, even through the
Note or Attachment is related to the parent entity (e.g. Account or Contact).
However, ContentVersion object follows a different approach. Rather than an
explicit 'IsPrivate' checkbox it uses a robust sharing model, one of the reasons
to convert to the new Files to begin with! In this sharing model, to
make a record private then it simpy isn't shared with any other users or records.
The caveat then is that these unshared (private) Files do not show up
contextually on any Salesforce record. By sharing the new File with the
original parent record then any user who has visibility to that parent record now
has access to this previously private attachment. Therefore, when converting
you have the option to specify whether the private attachments should
or should not be shared with the parent entity once converted into new File.

Learn more at:
* https://help.salesforce.com/apex/HTViewHelpDoc?id=notes_fields.htm


Selecting Parent IDs
--------------------
You may want to test conversion on a subset of records rather than convert
your entire database all at once. To do this you can specify `parentIds` on the
option classes which takes a Set of record ids who are the parent entities
that the notes or attachments belong to that you want to convert.

    ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions();
    options.parentIds = new Set<ID>{ 'id_of_record_whose_attachments_to_convert' };

    // then run batchable
    ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable( options );
    Database.executeBatch( batchable, 100 );


Max Documents or Versions Published Governor Limit
--------------------------------------------------
When converting classic Notes & Attachments the new data is stored in the `ContentVersion` object.
There is a [limit to how many of these records can be created in a 24 hour period](https://help.salesforce.com/articleView?id=limits_general.htm&language=en_US&type=0). If you have a lot of Notes & Attachments to convert plan around this limit and split the work across multiple days.


Background
----------
In the Winter 16 release, Salesforce introduces a new related list called Files.
This new related list specifically shows only Chatter Files shared to the record.
Seeing as this is the future of Salesforce content, you may want to plan migrating
your existing Attachments to Chatter Files. That is the function of this project.

Migrating to Files instead of Attachments [is a good idea](https://admin.salesforce.com/5-reasons-use-files-related-list) because Chatter Files
provide you much more capabilities around sharing the file with other users, groups, and records.
It also supports file previews and revisions. It is the future of managing content in Salesforce.

Learn more at:
* https://admin.salesforce.com/5-reasons-use-files-related-list
* https://www.salesforce.com/blog/2012/04/chatter-files-a-better-option-for-attaching-files-to-records.html
* http://docs.releasenotes.salesforce.com/en-us/winter16/release-notes/rn_chatter_files_related_list.htm
* https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_contentversion.htm


Other Considerations
--------------------
* Add the "Files" related list to your page layouts.
* Enable files setting [Files uploaded to the Attachments related list on records are uploaded as Salesforce Files, not as attachments](https://releasenotes.docs.salesforce.com/en-us/spring16/release-notes/rn_files_notes_attachments_list.htm).


Credits
-------
* Code adapted from Chirag Mehta's [post on stackoverflow](http://stackoverflow.com/questions/11395148/related-content-stored-in-which-object-how-to-create-related-content-recor).