/**
 * Designed for mass converting all notes in system or just those
 * belonging to specific parent records as indicated in the configuration options.
 *
 * Actual conversion for each batch execution is delegated to ConvertNotesToContentNotesService.
 */
public class ConvertNotesToContentNotesBatchable implements Database.Batchable<SObject>, Database.Stateful {

    private ConvertNotesToContentNotesOptions options { get; set; }

    public ConvertNotesToContentNotesBatchable() {
        this( new ConvertNotesToContentNotesOptions() );
    }

    public ConvertNotesToContentNotesBatchable( ConvertNotesToContentNotesOptions options ) {
        this.options = options;
    }

    // ----------------------------------------------------------

    public Database.QueryLocator start( Database.BatchableContext context ) {

        System.debug( '[ConvertNotesToContentNotesBatchable.start] Starting: ' + context );
        System.debug( '[ConvertNotesToContentNotesBatchable.start] Options: ' + this.options );

        if ( this.options.parentIds == null ) {

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
                    parentId IN :this.options.parentIds
                    AND
                    owner.isActive = true
                ORDER BY
                    parentId
            ]);

        }
    }

    public void execute( Database.BatchableContext context, List<Note> notes ) {

        System.debug( '[ConvertNotesToContentNotesBatchable.execute] Executing: ' + context );
        System.debug( '[ConvertNotesToContentNotesBatchable.execute] Options: ' + this.options );

        ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService( this.options );

        List<ConvertNotesToContentNotesService.ConversionResult> results = service.convert( notes );

        System.debug( '[ConvertNotesToContentNotesBatchable.execute] Conversion results: ' + results );

        if ( this.options.conversionResultEmailNotificationAddresses != null ) {
            ConvertNotesToContentNotesEmailService.sendEmail( this.options.conversionResultEmailNotificationAddresses, results );
        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( '[ConvertNotesToContentNotesBatchable.finish] Finishing: ' + context );
        System.debug( '[ConvertNotesToContentNotesBatchable.finish] Options: ' + this.options );

    }

}