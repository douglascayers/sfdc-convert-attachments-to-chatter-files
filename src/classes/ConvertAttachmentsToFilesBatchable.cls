/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Designed for mass converting all attachments in system or just those
 * belonging to specific parent records as indicated in the configuration options.
 *
 * Actual conversion for each batch execution is delegated to ConvertAttachmentsToFilesService.
 */
global without sharing class ConvertAttachmentsToFilesBatchable implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible
    private List<ConvertAttachmentsToFilesService.ConversionResult> mockResults { get; set; }

    @TestVisible
    private Exception mockException { get; set; }

    // ----------------------------------------------------------

    @TestVisible
    private ConvertAttachmentsToFilesOptions options { get; set; }

    @TestVisible
    private Integer conversionCount { get; set; } // the number of attachments converted by this batchable

    global ConvertAttachmentsToFilesBatchable() {
        this( new ConvertAttachmentsToFilesOptions() );
    }

    // not exposed to subscriber orgs, want users to configure the custom setting
    public ConvertAttachmentsToFilesBatchable( ConvertAttachmentsToFilesOptions options ) {
        this.options = options;
        this.conversionCount = 0;
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

        if ( this.conversionCount >= this.options.maxRecordsToConvert ) {
            System.debug( 'Reached max records to convert; aborting job: ' + context );
            System.abortJob( context.getJobId() );
            return;
        }

        SavePoint sp = Database.setSavePoint();

        try {

            System.debug( '[ConvertAttachmentsToFilesBatchable.execute] Executing: ' + context );
            System.debug( '[ConvertAttachmentsToFilesBatchable.execute] Options: ' + this.options );

            ConvertAttachmentsToFilesService service = new ConvertAttachmentsToFilesService( this.options );

            List<ConvertAttachmentsToFilesService.ConversionResult> results = service.convert( attachments );

            if ( Test.isRunningTest() ) {

                if ( this.mockException != null ) {
                    throw this.mockException;
                }

                if ( this.mockResults != null ) {
                    results = mockResults;
                }

            }

            ConvertAttachmentsToFilesLogger.log( context.getJobId(), results );

            for ( ConvertAttachmentsToFilesService.ConversionResult result : results ) {
                if ( result.status == ConvertAttachmentsToFilesService.ConversionResultStatus.CONVERTED ) {
                    this.conversionCount++;
                }
            }

        } catch ( Exception e ) {

            Database.rollback( sp );

            ConvertAttachmentsToFilesLogger.log( context.getJobId(), e );

        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( '[ConvertAttachmentsToFilesBatchable.finish] Finishing: ' + context );
        System.debug( '[ConvertAttachmentsToFilesBatchable.finish] Options: ' + this.options );

        ConvertAttachmentsToFilesLogger.sendApexExceptionEmailIfAnyErrorsSince( context.getJobId() );

    }

}