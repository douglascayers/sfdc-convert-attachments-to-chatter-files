Convert Notes & Attachments to Chatter Files
============================================

This project contains multiple apex classes (triggers, queueables, batchables, schedulables) to assist with the manual or automatic conversion of
classic [Notes](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_note.htm) and [Attachments](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_attachment.htm)
into [Enhanced Notes](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_contentnote.htm) and [Chatter Files](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_contentversion.htm)
to take advantage of rich-text, and more sophisticated sharing and file revisions.
You may like to read my [blog post](https://douglascayers.wordpress.com/2015/10/10/salesforce-convert-attachments-to-chatter-files/) on the topic.


Installation
------------
You can easily install these components to your org straight from github or as an unmanaged package.
* [Deploy from Github](https://githubsfdeploy.herokuapp.com)
* [See Releases Page](https://github.com/DouglasCAyers/sfdc-convert-attachments-to-chatter-files/releases)


Usage
-----
There are three main ways to perform the conversions:

1. Manually invoke a batchable class for a one-time conversion of notes or attachments in database
2. Schedule a batchable class for periodic conversions of notes or attachments in database (e.g. daily, monthly)
3. Enable a trigger to near real-time convert notes or attachments as they are inserted

When you choose option `1` or `2` then you likely are kicking off the process using Developer Console.
You will want to configure some preferences with the `ConvertAttachmentsToFilesOptions` or `ConvertNotesToContentNotesOptions` classes
when you execute or schedule the pertinent batchable class, `ConvertAttachmentsToFilesBatchable` or `ConvertNotesToContentNotesBatchable`.

When you choose option `3` then you configure your preferences instead using **custom settings**.
This project includes two custom settings, **Convert Attachments to Files Settings** and **Convert Notes to ContentNotes Settings**.
They are hierarchical settings and you likely only need the default organization level values configured.
Please note, the settings you can toggle available to you are exactly the same regardless which option (1, 2, or 3) you choose.

|Attachment Settings                     |Description                                                                                      |
|----------------------------------------|-------------------------------------------------------------------------------------------------|
|Convert in Near Real Time?              |Enables trigger to convert attachments to files. Invokes queuable to process them asynchronously.|
|Convert Inbound Email Attachments?      |Case Feed Only: converts inbound email attachments to files shared with the Case.                |
|Share Private Attachments?              |If private attachment is converted, will share its access with the parent record or not.         |
|Delete Attachment Once Converted?       |Deletes attachment once converted. This can save storage space. Backup your data!                |
|Convert If Feed Tracking Disabled?      |If parent record does not support Chatter Files, still convert it? It won't be shared to record. |
|Conversion Result Email Notifications   |Comma-delimited list of email addresses to send conversion success/failure results to.           |
|Chatter Post to Case Inbound Email File?|TODO: Chatter Post with converted File so Case Team can quickly and easily collaborate on it.    |


|Note Settings                           |Description                                                                                         |
|----------------------------------------|----------------------------------------------------------------------------------------------------|
|Convert in Near Real Time?              |Enables trigger to convert notes to enhanced notes. Invokes queuable to process them asynchronously.|
|Share Private Attachments?              |If private note is converted, will share its access with the parent record or not.                  |
|Delete Attachment Once Converted?       |Deletes note once converted. This can save storage space. Backup your data!                         |
|Convert If Feed Tracking Disabled?      |If parent record does not support Chatter Files, still convert it? It won't be shared to record.    |
|Conversion Result Email Notifications   |Comma-delimited list of email addresses to send conversion success/failure results to.              |


Examples
--------

*Manually Invoke Batchable Class*

    // default options per custom setting
    Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getInstance();
    ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions( settings );

    // or, explicitly set options for this run
    ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions();
    options.deleteAttachmentsUponConversion = false;

    // then run batchable
    ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable( options );
    Database.executeBatch( batchable, 100 );

*Schedule Batachable Class*

    // default options per custom setting
    Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getInstance();
    ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions( settings );

    // or, explicitly set options for this run
    ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions();
    options.deleteAttachmentsUponConversion = false;

    // then schedule job
    // note, to change options after job is scheduled you need to stop the job and kick it off again with new option selections
    System.schedule( 'Convert Attachments to Files Job', '0 0 13 * * ?', new ConvertAttachmentsToFilesSchedulable( options ) );

*Enable Trigger for Real-Time*

    In Setup, check or uncheck the "Convert in Real Time?" custom setting.
    The apex triggers look at those values in real-time to know whether to convert or not.


Private Notes / Attachments
---------------------------
Classic Notes & Attachments have an 'IsPrivate' checkbox field that when selected
makes the record only visible to the owner and administrators, even through the
Note or Attachment is related to the parent entity (e.g. Account or Contact).
However, ContentVersion object follows a different approach. Rather than an
explicit 'IsPrivate' checkbox it uses a robust sharing model, one of the reasons
to convert to the new Notes and Files to begin with! In this sharing model, to
make a record private then it simpy isn't shared with any other users or records.
The caveat then is that these unshared (private) Notes and Files do not show up
contextually on any Salesforce record. By sharing the new Note or File with the
original parent record then any user who has visibility to that parent record now
has access to this previously private note or attachment. Therefore, when converting
you have the option to specify whether the private notes and attachments should
or should not be shared with the parent entity once converted into new Note or File.

Learn more at:
* https://help.salesforce.com/apex/HTViewHelpDoc?id=notes_fields.htm


Inactive Owners
---------------
ContentVersion records cannot be owned by inactive users.
Attempting to causes error: "INACTIVE_OWNER_OR_USER".
Even with the `Update Records with Inactive Owners` system permission,
Salesforce will not allow you to set the owner id of a ContentVersion record
neither on insert or update. You also cannot share the ContentVersion with inactive users,
so we cannot even create ContentVersionLinks to those users.
If there is no way to associate a converted file with the original inactive owner
then the new file would be owned by the current user running the conversion only,
that may not be of any use to anyone so this edge case is ignored.
If you want notes or attachments owned by inactive users converted, please re-assign them
to an active user then run the conversion code.


Selecting Parent IDs
--------------------
You may want to test conversion on a subset of records rather than convert
your entire database all at once. To do this you can specify `parentIds` on the
option classes which takes a Set of record ids who are the parent entities
that the notes or attachments belong to that you want to convert.


Background
----------
In the Winter 16 release, Salesforce introduces a new related list called Files.
This new related list specifically shows only Chatter Files shared to the record.
Seeing as this is the future of Salesforce content, you may want to plan migrating
your existing Attachments to Chatter Files. That is the function of this class.

Migrating to Files instead of Attachments is a good idea because Chatter Files
provide you much more capabilities around sharing the file with other users, groups, and records.
It also supports file previews and revisions. It is the future of managing content in Salesforce.

Furthermore, Salesforce released new Notes feature that supports rich-text and the same sharing capabilities as Chatter Files.
In fact, the new Notes feature is built on top of the same Chatter Files technology!

Learn more at:
* http://docs.releasenotes.salesforce.com/en-us/winter16/release-notes/rn_chatter_files_related_list.htm#topic-title
* https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_contentversion.htm
* http://docs.releasenotes.salesforce.com/en-us/winter16/release-notes/notes_admin_setup.htm

Example page layout with the new **Files** and **Notes** related lists added:
![screenshot](/images/related-lists-pre-conversion.png)

Example results after running the conversion code:
![screenshot](/images/related-lists-post-conversion.png)


Pre-Requisites
--------------
To install this package then you must have [enhanced notes enabled](http://docs.releasenotes.salesforce.com/en-us/winter16/release-notes/notes_admin_setup.htm).
![screenshot](/images/notes-settings.png)


Credits
-------
* Code adapted from Chirag Mehta's [post on stackoverflow](http://stackoverflow.com/questions/11395148/related-content-stored-in-which-object-how-to-create-related-content-recor).
* Note content escaping adapted from David Reed's [project](https://github.com/davidmreed/DMRNoteAttachmentImporter).