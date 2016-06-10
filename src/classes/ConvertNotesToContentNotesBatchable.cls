/**
 * Converts standard Notes into fancy ContentNotes.
 * If desired, you may choose to have the old notes deleted upon conversion.
 * By default the original note records will not be deleted and continue to take up storage.
 *
 * Usage:
 *      Database.executeBatch( new ConvertNotesToContentNotesBatchable(), 200 );
 *
 *      Boolean deleteNotesUponConversion = true;
 *      Database.executeBatch( new ConvertNotesToContentNotesBatchable( deleteNotesUponConversion ), 200 );
 *
 * https://github.com/DouglasCAyers/sfdc-convert-attachments-to-chatter-files
 */
public with sharing class ConvertNotesToContentNotesBatchable implements Database.Batchable<SObject> {

    // should the Notes be deleted upon conversion to ContentNote?
    // Deleting them reduces redundant data storage.
    // Make sure you've backed up your data before enabling this.
    private Boolean deleteNotesUponConversion;

    // Constructor
    public ConvertNotesToContentNotesBatchable() {
        this( false );
    }

    // Constructor
    public ConvertNotesToContentNotesBatchable( Boolean deleteNotesUponConversion ) {
        this.deleteNotesUponConversion = deleteNotesUponConversion;
    }

    public Database.QueryLocator start( Database.BatchableContext context ) {

        System.debug( 'Starting: ' + context );

        return Database.getQueryLocator([
            SELECT
                id, ownerId, parentId, title, body
            FROM
                Note
        ]);
    }

    public void execute( Database.BatchableContext context, List<Note> notes ) {

        System.debug( 'Executing: ' + context );

        /*
         * Step 1
         * Convert Notes to ContentNotes
         */

        List<ContentNote> contentNotes = new List<ContentNote>();

        for ( Note note : notes ) {

            // oddly, ContentNote object does not allow you to set ownerId
            // nor can you set CreatedById or CreatedDate even with 'Create Audit Fields' permission
            // at best, to reproduce the record controls of the owner we'll try to add
            // that user as a 'collaborator' of this note so they can read/write it
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
                id, latestPublishedVersionId
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
                id, contentDocumentId
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

            // share the new note with the same parent entity of the old note
            contentDocumentLinks.add( new ContentDocumentLink(
                linkedEntityId = note.parentId,
                contentDocumentId = contentVersion.contentDocumentId,
                shareType = 'V'
            ));

            // by default, the current user will be the owner of the new note
            // so we need to make sure we aren't trying to redundantly share
            // access to this record with the same user else get error:
            // "INSUFFICIENT_ACCESS_OR_READONLY, Invalid sharing type C"
            if ( UserInfo.getUserId() != note.ownerId ) {
                contentDocumentLinks.add( new ContentDocumentLink(
                    linkedEntityId = note.ownerId,
                    contentDocumentId = contentVersion.contentDocumentId,
                    shareType = 'C'
                ));
            }

            // custom fields for history tracking and conversion purposes
            contentVersion.original_record_id__c = note.id;
            contentVersion.original_record_parent_id__c = note.parentId;

        }

        System.debug( 'inserting content document links: ' + contentDocumentLinks );
        insert contentDocumentLinks;

        System.debug( 'updating content versions: ' + contentVersions );
        update contentVersions;

        if ( this.deleteNotesUponConversion ) {
            System.debug( 'deleting original notes: ' + notes );
            delete notes;
        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( 'Finishing: ' + context );

    }

}
