Convert Notes & Attachments to Chatter Files
============================================

<a href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04tj0000001aZiP">
  <img alt="Deploy to Salesforce"
       src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png">
</a>

Batchable apex classes that convert notes and attachments into chatter files to take advantage of rich-text, more sophisticated sharing and file revisions. Read my [blog post](https://douglascayers.wordpress.com/2015/10/10/salesforce-convert-attachments-to-chatter-files/) on the topic.


Usage
-----
In Salesforce, open the Developer Console and run this anonymous apex snippet:

    Database.executeBatch( new ConvertAttachmentsToFilesBatchable(), 100 );
    Database.executeBatch( new ConvertNotesToContentNotesBatchable(), 100 );

If you run into governor limits, you may need to reduce the batch size.

You can also optionally choose to delete the original notes and attachments upon conversion.
Pass the boolean value `true` into the batchable class constructor to enable deletion.

    Boolean deleteUponConversion = true;
    Database.executeBatch( new ConvertAttachmentsToFilesBatchable( deleteUponConversion ), 100 );
    Database.executeBatch( new ConvertNotesToContentNotesBatchable( deleteUponConversion ), 100 );


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
