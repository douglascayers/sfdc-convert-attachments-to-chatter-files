/**
 * Designed for mass converting all attachments in system or just those
 * belonging to specific parent records as indicated in the configuration options.
 *
 * Actual conversion for each batch execution is delegated to ConvertAttachmentsToFilesService.
 */
public class ConvertAttachmentsToFilesBatchable implements Database.Batchable<SObject>, Database.Stateful {

    private ConvertAttachmentsToFilesOptions options { get; set; }

    public ConvertAttachmentsToFilesBatchable() {
        this( new ConvertAttachmentsToFilesOptions() );
    }

    public ConvertAttachmentsToFilesBatchable( ConvertAttachmentsToFilesOptions options ) {
        this.options = options;
    }

    // ----------------------------------------------------------

    public Database.QueryLocator start( Database.BatchableContext context ) {

        System.debug( '[ConvertAttachmentsToFilesBatchable.start] Starting: ' + context );
        System.debug( '[ConvertAttachmentsToFilesBatchable.start] Options: ' + this.options );

        if ( this.options.parentIds == null ) {

            return Database.getQueryLocator([
                SELECT
                    id, ownerId, owner.isActive, parentId, name, body, description, isPrivate
                FROM
                    Attachment
                WHERE
                    owner.isActive = true
                ORDER BY
                    parentId
            ]);

        } else {

            return Database.getQueryLocator([
                SELECT
                    id, ownerId, owner.isActive, parentId, name, body, description, isPrivate
                FROM
                    Attachment
                WHERE
                    parentId IN :this.options.parentIds
                    AND
                    owner.isActive = true
                ORDER BY
                    parentId
            ]);

        }
    }

    public void execute( Database.BatchableContext context, List<Attachment> attachments ) {

        System.debug( '[ConvertAttachmentsToFilesBatchable.execute] Executing: ' + context );
        System.debug( '[ConvertAttachmentsToFilesBatchable.execute] Options: ' + this.options );

        ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService( this.options );

        List<ConvertAttachmentsToFilesService.ConversionResult> results = service.convert( attachments );

        System.debug( '[ConvertAttachmentsToFilesBatchable.execute] Conversion results: ' + results );

        if ( this.options.conversionResultEmailNotificationAddresses != null ) {
            ConvertAttachmentsToFilesEmailService.sendEmail( this.options.conversionResultEmailNotificationAddresses, results );
        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( '[ConvertAttachmentsToFilesBatchable.finish] Finishing: ' + context );
        System.debug( '[ConvertAttachmentsToFilesBatchable.finish] Options: ' + this.options );

    }

}