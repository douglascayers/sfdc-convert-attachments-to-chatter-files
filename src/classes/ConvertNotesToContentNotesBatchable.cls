/**
 * -------------------------------------------------------------------------
 * Overview
 * -------------------------------------------------------------------------
 * Converts standard Notes into fancy ContentNotes.
 * If desired, you may choose to have the old notes deleted upon conversion.
 * By default the original note records will not be deleted and continue to take up storage.
 * Notes owned by inactive users will not be converted.
 *
 * -------------------------------------------------------------------------
 * Private Notes:
 * -------------------------------------------------------------------------
 * Classic Notes have an 'IsPrivate' checkbox field that restricts
 * visibility to the owner and administrators, all while the note is related to the parent record.
 * However, the only way to make the new ContentNote record private is to not have it shared
 * with any other user, group, or record. So... when converting notes, you may specify an option
 * to either (true) share the converted private note with the parent record and thereby any users
 * who have visibility to the parent record now also have visibility to this converted note or
 * (false) still convert the private note but it remains private, only accessible by the owner
 * but will not be found contextually on any record in Salesforce.
 *
 * -------------------------------------------------------------------------
 * Inactive Owners:
 * -------------------------------------------------------------------------
 * ContentNote records cannot be owned by inactive users.
 * Attempting to causes error: "INACTIVE_OWNER_OR_USER".
 * Even with the 'Update Records with Inactive Owners' system permission,
 * Salesforce will not allow you to set the owner id of a ContentNote record
 * neither on insert or update. You also cannot share the ContentNote with inactive users,
 * so we cannot even create ContentDocumentLinks to those users.
 * If there is no way to associate a converted note with the original inactive owner
 * then the new note would be owned by the current user running the conversion only,
 * that may not be of any use to anyone so this edge case is ignored.
 * If you want notes owned by inactive users converted, please re-assign them
 * to an active user then run the conversion code.
 *
 * -------------------------------------------------------------------------
 * Usage:
 * -------------------------------------------------------------------------
 *
 *      // use default options:
 *      //  - don't delete records upon conversion
 *      //  - don't share private notes with parent record (keep them private after conversion)
 *      //  - convert all notes in the system
 *      Database.executeBatch( new ConvertNotesToContentNotesBatchable(), 200 );
 *
 *      // customize conversion options
 *      ConvertNotesToContentNotesBatchable batchable = new ConvertNotesToContentNotesBatchable();
 *      batchable.deleteNotesUponConversion = true;
 *      batchable.sharePrivateNotesWithParentRecord = true;
 *      Database.executeBatch( batchable, 100 );
 *
 *      // scope conversion to specific parent records
 *      ConvertNotesToContentNotesBatchable batchable = new ConvertNotesToContentNotesBatchable();
 *      batchable.parentIds = new Set<ID>{ '001j0000003ZS24', '001j0000003ZS1z' };
 *      Database.executeBatch( batchable, 100 );
 *
 * https://github.com/DouglasCAyers/sfdc-convert-attachments-to-chatter-files
 */
public with sharing class ConvertNotesToContentNotesBatchable implements Database.Batchable<SObject> {

    // Should the Notes be deleted upon conversion to ContentNote?
    // Deleting them reduces redundant data storage.
    // Make sure you've backed up your data before enabling this.
    public Boolean deleteNotesUponConversion = false;

    // Classic Notes have a 'IsPrivate' field that when checked the note
    // is only visible to the owner and administrators. To preserve this
    // then the new ContentNote cannot be shared with the parent record
    // because doing so would grant any user who has at least read access
    // to the record to now have read access to the previously private note content.
    // The alternative is to still convert the note but don't share it with the
    // parent record; however, now the new Notes are not categorized at all
    // so these now technically private new Notes have no context beyond their content.
    // As with the delete option, I err on the side of caution and do nothing unless you enable this option.
    public Boolean sharePrivateNotesWithParentRecord = false;

    // Scope the conversion to just notes related to specific records
    // if null then ALL notes in the system will be converted
    // if empty then NO notes will be converted
    // if non-empty then only notes related to those records will be converted
    public Set<ID> parentIds = null;

    // ----------------------------------------------------------

    public Database.QueryLocator start( Database.BatchableContext context ) {

        System.debug( 'Starting: ' + context );
        System.debug( 'deleteNotesUponConversion = ' + this.deleteNotesUponConversion );
        System.debug( 'sharePrivateNotesWithParentRecord = ' + this.sharePrivateNotesWithParentRecord );
        System.debug( 'parentIds = ' + this.parentIds );

        if ( this.parentIds == null ) {

            return Database.getQueryLocator([
                SELECT
                    id, ownerId, owner.isActive, parentId, title, body, isPrivate
                FROM
                    Note
                WHERE
                    owner.isActive = true
                ORDER BY
                    parentId
            ]);

        } else {

            return Database.getQueryLocator([
                SELECT
                    id, ownerId, owner.isActive, parentId, title, body, isPrivate
                FROM
                    Note
                WHERE
                    parentId IN :this.parentIds
                    AND
                    owner.isActive = true
                ORDER BY
                    parentId
            ]);

        }
    }

    public void execute( Database.BatchableContext context, List<Note> notes ) {

        System.debug( 'Executing: ' + context );

        /*
         * Step 1
         * Convert Notes to ContentNotes
         */

        List<ContentNote> contentNotes = new List<ContentNote>();

        for ( Note note : notes ) {

            // oddly, ContentNote object does not allow you to set OwnerId
            // nor can you set CreatedById or CreatedDate even with 'Create Audit Fields' permission
            // but we can update the generated ContentVersion record with original owner id later
            contentNotes.add( new ContentNote(
                title = note.title,
                content = Blob.valueOf( ( note.body == null ) ? '' : note.body )
            ));

        }

        insert contentNotes;

        /*
         * Step 2
         * Requery ContentNotes to get latest published version id so that we can
         * query the ContentVersion records to know the generated content document id
         * so that we can create ContentDocumentLinks between the document and note's
         * parent record and owner. Doing so will share the note so it's accessible by others.
         */

        Map<ID, ContentNote> contentNotesMap = new Map<ID, ContentNote>([
            SELECT
                id, ownerId, latestPublishedVersionId
            FROM
                ContentNote
            WHERE
                id IN :contentNotes
        ]);

        System.assertEquals( contentNotes.size(), contentNotesMap.size() );

        // Create map of the new note ContentVersion id and the old Note record
        // we will use this later to create ContentDocumentLinks between
        // the ContentVersion record and the old Note's parent.
        // To ensure in our loop that the index variable points to the same
        // ContentNote and Note records that are related then we had to make
        // sure that we iterated contentNotes variable exactly how we defined it
        // originally. When we requeried the ContentNote fields to get latestPublishedVersionId field
        // you notice we did so into a new map variable. That is because we can't
        // guarantee the sort order would come back on that query in exactly the
        // same order as the original old Notes. And since ContentNote doesn't support
        // custom fields we couldn't put any cross-reference data there to make this
        // part easier. Therefore, you'll notice that in the contentVersionToNotesMap
        // variable below that we want the key to be the content version id of the new note
        // but to look that up we have to go through the other content notes map. Whew!
        Map<ID, Note> contentVersionToNotesMap = new Map<ID, Note>();
        for ( Integer i = 0; i < contentNotes.size(); i++ ) {
            contentVersionToNotesMap.put(
                contentNotesMap.get( contentNotes[i].id ).latestPublishedVersionId,
                notes[i]
            );
        }

        System.debug( 'contentVersionToNotesMap = ' + contentVersionToNotesMap );

        /*
         * Step 3
         * Requery ContentVersions to get generated content document id (so we can link records to the content)
         * and the original note parent id (the record we want to share the content with)
         */

        List<ContentVersion> contentVersions = new List<ContentVersion>([
            SELECT
                id, ownerId, contentDocumentId
            FROM
                ContentVersion
            WHERE
                id IN :contentVersionToNotesMap.keySet()
        ]);

        System.debug( 'contentVersions = ' + contentVersions );
        System.assertEquals( contentNotes.size(), contentVersions.size() );

        /*
         * Step 4
         * Create ContentDocumentLinks to share the new content
         * with the same parent record as the source note
         */

        List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();

        for ( ContentVersion contentVersion : contentVersions ) {

            Note note = contentVersionToNotesMap.get( contentVersion.id );

            System.debug( 'contentVersion = ' + contentVersion );
            System.debug( 'oldNote = ' + note );

            // retain original ownership
            contentVersion.ownerId = note.ownerId;

            // custom fields for history tracking and conversion purposes
            contentVersion.original_record_id__c = note.id;
            contentVersion.original_record_parent_id__c = note.parentId;
            contentVersion.original_record_owner_id__c = note.ownerId;

            // should converted note be shared with parent?
            if ( !note.isPrivate || ( note.isPrivate && this.sharePrivateNotesWithParentRecord ) ) {

                // share the new note with the same parent entity of the old note
                // any user with visibility to this record has visibility to this note
                contentDocumentLinks.add( new ContentDocumentLink(
                    linkedEntityId = note.parentId,
                    contentDocumentId = contentVersion.contentDocumentId,
                    shareType = 'V'
                ));

            }

        }

        System.debug( 'updating content versions: ' + contentVersions );
        if ( contentVersions.size() > 0 ) {
            update contentVersions;
        }

        System.debug( 'inserting content document links: ' + contentDocumentLinks );
        if ( contentDocumentLinks.size() > 0 ) {
            insert contentDocumentLinks;
        }

        if ( this.deleteNotesUponConversion ) {
            System.debug( 'deleting original notes: ' + notes );
            delete notes;
        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( 'Finishing: ' + context );

    }

}