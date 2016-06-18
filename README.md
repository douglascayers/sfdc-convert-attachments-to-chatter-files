Convert Notes & Attachments to Chatter Files
============================================

Batchable apex classes that convert notes and attachments into chatter files to take advantage of rich-text, more sophisticated sharing and file revisions. Read my [blog post](https://douglascayers.wordpress.com/2015/10/10/salesforce-convert-attachments-to-chatter-files/) on the topic.


Installation
------------
You can easily install these components to your org straight from github or as an unmanaged package.
* [Deploy from Github](https://githubsfdeploy.herokuapp.com)
* [See Releases Page](https://github.com/DouglasCAyers/sfdc-convert-attachments-to-chatter-files/releases)


Usage
-----
The quickest way to kick off the conversion is to use the Developer Console.
Navigate to Developer Console > Debug > Open Execute Anonymous Window.

The default options are to **not** delete the records after conversion,
and to ignore **private** notes and attachments or records owned by **inactive** owners.
Please read the specific sections below about those topics to learn why
and what to consider before enabling the options to override the defaults.

*Default Options*

    Database.executeBatch( new ConvertNotesToContentNotesBatchable(), 200 );
    Database.executeBatch( new ConvertAttachmentsToFilesBatchable(), 200 );

*Customizable Options (set one or more as desired)*

    ConvertNotesToContentNotesBatchable notesBatchable = new ConvertNotesToContentNotesBatchable();
    notesBatchable.deleteNotesUponConversion = true;
    notesBatchable.sharePrivateNotesWithParentRecord = true;
    notesBatchable.parentIds = new Set<ID>{ '001j0000003ZS24', '001j0000003ZS1z' };
    Database.executeBatch( notesBatchable, 100 );

    ConvertAttachmentsToFilesBatchable filesBatchable = new ConvertAttachmentsToFilesBatchable();
    filesBatchable.deleteAttachmentsUponConversion = true;
    filesBatchable.sharePrivateAttachmentsWithParentRecord = true;
    filesBatchable.parentIds = new Set<ID>{ '001j0000003ZS24', '001j0000003ZS1z' };
    Database.executeBatch( filesBatchable, 100 );

If you run into governor limits, you may need to reduce the batch size.


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
batchable classes which takes a Set of record ids who are the parent entities
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

Furthermore, Salesforce released new Notes feature that supports rich-text and the same sharing capabilities as Chatter Files. In fact, the new Notes feature is built on top of the same Chatter Files technology!

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
Code adapted from Chirag Mehta's post on stackoverflow.
http://stackoverflow.com/questions/11395148/related-content-stored-in-which-object-how-to-create-related-content-recor
