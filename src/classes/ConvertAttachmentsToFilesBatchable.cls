/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Designed for mass converting all attachments in system or just those
 * belonging to specific parent records as indicated in the configuration options.
 *
 * Actual conversion for each batch execution is delegated to ConvertAttachmentsToFilesService.
 */
public with sharing class ConvertAttachmentsToFilesBatchable implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible
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

        if ( this.options == null || this.options.parentIds == null ) {

            return Database.getQueryLocator([
                SELECT
                    id, parentId, ownerId, name, description, body, isPrivate,
                    createdById, createdDate, lastModifiedById, lastModifiedDate
                FROM
                    Attachment
                ORDER BY
                    parentId
            ]);

        } else {

            return Database.getQueryLocator([
                SELECT
                    id, parentId, ownerId, name, description, body, isPrivate,
                    createdById, createdDate, lastModifiedById, lastModifiedDate
                FROM
                    Attachment
                WHERE
                    parentId IN :this.options.parentIds
                ORDER BY
                    parentId
            ]);

        }

    }

    public void execute( Database.BatchableContext context, List<Attachment> attachments ) {

        try {

            System.debug( '[ConvertAttachmentsToFilesBatchable.execute] Executing: ' + context );
            System.debug( '[ConvertAttachmentsToFilesBatchable.execute] Options: ' + this.options );

            ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService( this.options );

            List<ConvertAttachmentsToFilesService.ConversionResult> results = service.convert( attachments );

            ConvertAttachmentsToFilesLogger.log( results );

        } catch ( Exception e ) {

            ConvertAttachmentsToFilesLogger.log( e );

        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( '[ConvertAttachmentsToFilesBatchable.finish] Finishing: ' + context );
        System.debug( '[ConvertAttachmentsToFilesBatchable.finish] Options: ' + this.options );

    }

}