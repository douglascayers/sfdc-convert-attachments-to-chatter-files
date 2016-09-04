/**
 * Designed to be invoked within a trigger or some other scenario where you
 * need exactly one batch of records (up to 200 records) to be converted to Files.
 *
 * Actual conversion for the execution is delegated to ConvertAttachmentsToFilesService.
 */
public class ConvertAttachmentsToFilesQueueable implements Queueable {

    private ConvertAttachmentsToFilesOptions options { get; set; }

    private Set<ID> attachmentIds { get; set; }

    public ConvertAttachmentsToFilesQueueable( Set<ID> attachmentIds ) {
        this( attachmentIds, new ConvertAttachmentsToFilesOptions() );
    }

    public ConvertAttachmentsToFilesQueueable( Set<ID> attachmentIds, ConvertAttachmentsToFilesOptions options ) {
        this.attachmentIds = attachmentIds;
        this.options = options;
    }

    public void execute( QueueableContext context ) {

        System.debug( '[ConvertAttachmentsToFilesQueueable.execute] Executing: ' + context );

        List<Attachment> attachments = new List<Attachment>([
            SELECT
                id, parentId, ownerId, name, description, body, isPrivate
            FROM
                Attachment
            WHERE
                id IN :this.attachmentIds
                AND
                owner.isActive = true
            ORDER BY
                parentId
        ]);

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService( this.options );

        List<ConvertAttachmentsToFilesService.ConversionResult> results = service.convert( attachments );

        System.debug( '[ConvertAttachmentsToFilesQueueable.execute] Conversion results: ' + results );

    }

}