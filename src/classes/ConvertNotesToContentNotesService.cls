/**
 * Work horse that does the actual note to content note conversion.
 */
public class ConvertNotesToContentNotesService {

    private ConvertNotesToContentNotesOptions options { get; set; }

    public ConvertNotesToContentNotesService() {
        this( new ConvertNotesToContentNotesOptions() );
    }

    public ConvertNotesToContentNotesService( ConvertNotesToContentNotesOptions options ) {
        this.options = options;
    }

    /**
     * Each note record should have these fields populated:
     *  - Id
     *  - ParentId
     *  - OwnerId (of an active user)
     *  - Title
     *  - Body
     *  - IsPrivate
     */
    public List<ConversionResult> convert( List<Note> notes ) {

        System.debug( '[ConvertNotesToContentNotesService.convert] Options: ' + this.options );

        List<ConversionRequest> conversionRequests = buildConversionRequests( notes );

        // noteId ==> conversion result
        // as a map for easy retrieval throughout the various steps doing the conversion
        // and creation of content document links to share new content note with parent record.
        // we update the message field on the result occasionally in subsequent steps
        Map<ID, ConversionResult> conversionResultsMap = new Map<ID, ConversionResult>();

        /*
         * Step 0
         * Filter notes by whether their parent object supports feed tracking or not.
         * If parent doesn't support feed tracking then we can't create ContentDocumentLink
         * records sharing the content note with the parent record.
         */

        List<ConversionRequest> requestsToConvert = new List<ConversionRequest>();

        for ( ConversionRequest request : conversionRequests ) {

            Note note = request.note;
            SObjectType parentSObjectType = request.shareToEntityId.getSObjectType();
            DescribeSObjectResult parentDescribe = parentSObjectType.getDescribe();

            if ( parentDescribe.isFeedEnabled() || this.options.convertIfFeedTrackingDisabledOnParentObject ) {

                requestsToConvert.add( request );

            } else {

                ConversionResult result = new ConversionResult();
                result.success = false;
                result.noteId = note.id;
                result.message  = 'Chatter Feed Tracking is not enabled for parent object type [' + parentSObjectType + ']. ';
                result.message += 'Either enable feed tracking or enable the [Convert If Feed Tracking Disabled?] custom setting.';

                System.debug( LoggingLevel.WARN, '[ConvertNotesToContentNotesService.convert] conversion result = ' + result );

                conversionResultsMap.put( note.id, result );

            }

        }

        /*
         * Step 1
         * Convert Notes to ContentNotes
         */

        List<ContentNote> contentNotes = new List<ContentNote>();

        for ( ConversionRequest request : requestsToConvert ) {

            Note note = request.note;

            // oddly, ContentNote object does not allow you to set OwnerId
            // nor can you set CreatedById or CreatedDate even with 'Create Audit Fields' permission
            // but we can update the generated ContentVersion record with original owner id later

            // also, it's important that we escape special characters
            // logic inspired by David Reed (http://www.ktema.org//2016/08/24/importing-notes-into-salesforce/)
            // https://help.salesforce.com/apex/HTViewSolution?id=000230867&language=en_US
            String noteBody = ( ( note.body == null ) ? '' : note.body )
                .escapeXml()
                .replace('\r\n', '<br>')
                .replace('\r', '<br>')
                .replace('\n', '<br>')
                .replace('&apos;', '&#39;')
            ;

            contentNotes.add( new ContentNote(
                title = note.title,
                content = Blob.valueOf( noteBody )
            ));

        }

        insert contentNotes;

        System.debug( '[ConvertNotesToContentNotesService.convert] contentNotes = ' + contentNotes );

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
        Map<ID, ConversionRequest> contentVersionToNotesMap = new Map<ID, ConversionRequest>();
        for ( Integer i = 0; i < contentNotes.size(); i++ ) {

            contentVersionToNotesMap.put(
                contentNotesMap.get( contentNotes[i].id ).latestPublishedVersionId,
                requestsToConvert[i]
            );

            ConversionResult result = new ConversionResult();
            result.success = true;
            result.contentNoteId = contentNotes[i].id;
            result.noteId = requestsToConvert[i].note.id;

            System.debug( '[ConvertNotesToContentNotesService.convert] conversion result = ' + result );

            conversionResultsMap.put( requestsToConvert[i].note.id, result );

        }

        System.debug( '[ConvertNotesToContentNotesService.convert] contentVersionToNotesMap = ' + contentVersionToNotesMap );

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

        System.debug( '[ConvertNotesToContentNotesService.convert] contentVersions = ' + contentVersions );
        System.assertEquals( contentNotes.size(), contentVersions.size() );

        /*
         * Step 4
         * Create ContentDocumentLinks to share the new content
         * with the same parent record as the source note
         */

        List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();

        for ( ContentVersion contentVersion : contentVersions ) {

            ConversionRequest request = contentVersionToNotesMap.get( contentVersion.id );
            Note note = request.note;

            System.debug( '[ConvertNotesToContentNotesService.convert] contentVersion = ' + contentVersion );
            System.debug( '[ConvertNotesToContentNotesService.convert] oldNote = ' + note );

            // retain original ownership
            // we couldn't set ownerId on create but we can on update
            contentVersion.ownerId = note.ownerId;

            // custom fields for history tracking and conversion purposes
            contentVersion.original_record_id__c = note.id;
            contentVersion.original_record_parent_id__c = note.parentId;
            contentVersion.original_record_owner_id__c = note.ownerId;

            SObjectType parentSObjectType = request.shareToEntityId.getSObjectType();
            DescribeSObjectResult parentDescribe = parentSObjectType.getDescribe();

            if ( parentDescribe.isFeedEnabled() ) {

                // should converted note be shared with parent?
                if ( !note.isPrivate || ( note.isPrivate && this.options.sharePrivateNotesWithParentRecord ) ) {

                    // share the new note with the same parent entity of the old note
                    // any user with visibility to this record has visibility to this note
                    contentDocumentLinks.add( new ContentDocumentLink(
                        linkedEntityId = request.shareToEntityId,
                        contentDocumentId = contentVersion.contentDocumentId,
                        shareType = 'V'
                    ));

                } else {

                    String message  = 'Not creating ContentDocumentLink to share ContentDocument (' + contentVersion.contentDocumentId + ') with Parent Record (' + request.shareToEntityId + ') because note record (' + note.id + ') is private. ';
                           message += 'Either make note record not private or enable the [Share Private Notes?] custom setting.';

                    conversionResultsMap.get( note.id ).message += ' ' + message;

                    System.debug( LoggingLevel.WARN, message );

                }

            } else {

                String message = 'Not creating ContentDocumentLink to share ContentDocument (' + contentVersion.contentDocumentId + ') with Parent Record (' + request.shareToEntityId + ') because [' + parentSObjectType + '] does not have Chatter Feed Tracking enabled.';

                conversionResultsMap.get( note.id ).message += ' ' + message;

                System.debug( LoggingLevel.WARN, message );

            }

        }

        // apply updates to content versions, specifically setting owner id to original note owner id
        if ( contentVersions.size() > 0 ) {

            System.debug( '[ConvertNotesToContentNotesService.convert] updating content versions: ' + contentVersions );
            update contentVersions;

        }

        // create share links between new content note and original note parent entity
        if ( contentDocumentLinks.size() > 0 ) {

            System.debug( '[ConvertNotesToContentNotesService.convert] inserting content document links: ' + contentDocumentLinks );
            insert contentDocumentLinks;

        }

        // lastly, delete the original notes that were successfully converted into files
        if ( this.options.deleteNotesUponConversion ) {

            List<Note> notesToDelete = new List<Note>();

            for ( ContentVersion contentVersion : contentVersions ) {
                notesToDelete.add( new Note( id = contentVersion.original_record_id__c ) );
            }

            System.debug( '[ConvertNotesToContentNotesService.convert] deleting original notes: ' + notesToDelete );

            delete notesToDelete;

        }

        return conversionResultsMap.values();
    }

    /**
     * Inspects each note and applies various logic to determine the entity that the newly converted note
     * should be shared with. For example, majority of notes converted to content notes will be shared with their original parent.
     * But some records may need to be shared with a different entity because their parent does not support Feed Tracking
     * and you want the note shared to another record. This capability was really intended just for note conversions
     * for handling Email-2-Case nuance, but I'm leaving the framework here "just in case". I know, I know.. YAGNI.. but OCD.
     */
    private List<ConversionRequest> buildConversionRequests( List<Note> notes ) {

        List<ConversionRequest> requests = new List<ConversionRequest>();

        for ( Note note : notes ) {

            ConversionRequest request = new ConversionRequest();
            request.note = note;
            request.shareToEntityId = note.parentId;

            requests.add( request );

        }

        return requests;
    }

    /**
     * Generally speaking, note conversions share the new file with the note's parent.
     * However, there may be instances where that is not possible and you want a "next best thing".
     * On the conversion request you can indicate the entity to share to if the not to it's actual parent.
     */
    public class ConversionRequest {

        // the record to convert into file; required
        public Note note { get; set; }

        // the entity to share the content note to via ContentDocumentLink record; required
        public ID shareToEntityId { get; set; }

    }

    public class ConversionResult {

        // true if note was converted; false otherwise
        public Boolean success { get; set; }

        // if of the note being converted, should always be populated
        public ID noteId { get; set; }

        // id of the converted note, if successful, null otherwise
        public ID contentNoteId { get; set; }

        // if not successful then the error message
        // even if success is true may include message if could not share note to intended parent entity
        public String message { get; set; }

        public ConversionResult() {
            this.success = false;
            this.message = '';
        }

    }

}