/**
 * Designed to be invoked within a trigger or some other scenario where you
 * need exactly one batch of records (up to 200 records) to be converted to ContentNotes.
 *
 * Actual conversion for the execution is delegated to ConvertNotesToContentNotesService.
 */
public class ConvertNotesToContentNotesQueueable implements Queueable {

    private ConvertNotesToContentNotesOptions options { get; set; }

    private Set<ID> noteIds { get; set; }

    public ConvertNotesToContentNotesQueueable( Set<ID> noteIds ) {
        this( noteIds, new ConvertNotesToContentNotesOptions() );
    }

    public ConvertNotesToContentNotesQueueable( Set<ID> noteIds, ConvertNotesToContentNotesOptions options ) {
        this.noteIds = noteIds;
        this.options = options;
    }

    public void execute( QueueableContext context ) {

        System.debug( '[ConvertNotesToContentNotesQueueable.execute] Executing: ' + context );

        List<Note> notes = new List<Note>([
            SELECT
                id, parentId, ownerId, title, body, isPrivate
            FROM
                Note
            WHERE
                id IN :this.noteIds
                AND
                owner.isActive = true
            ORDER BY
                parentId
        ]);

        ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService( this.options );

        List<ConvertNotesToContentNotesService.ConversionResult> results = service.convert( notes );

        System.debug( '[ConvertNotesToContentNotesQueueable.execute] Conversion results: ' + results );

        if ( this.options.conversionResultEmailNotificationAddresses != null ) {
            ConvertNotesToContentNotesEmailService.sendEmail( this.options.conversionResultEmailNotificationAddresses, results );
        }

    }

}