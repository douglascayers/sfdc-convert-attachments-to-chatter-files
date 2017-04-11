/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Designed for scheduling periodic job to perform batch conversion of attachments.
 */
public with sharing class ConvertAttachmentsToFilesSchedulable implements Schedulable {

    public Integer batchSize { get; set; }

    public ConvertAttachmentsToFilesSchedulable() {
        this( 200 );
    }

    public ConvertAttachmentsToFilesSchedulable( Integer batchSize ) {
        this.batchSize = batchSize;
    }

    public void execute( SchedulableContext context ) {

        SavePoint sp = Database.setSavePoint();

        DateTime startTime = DateTime.now();

        try {

            // we use the instance rather than org defaults here to support
            // overrides on a user or profile level
            Convert_Attachments_to_Files_Settings__c settings = Convert_Attachments_to_Files_Settings__c.getInstance();

            ConvertAttachmentsToFilesOptions options = new ConvertAttachmentsToFilesOptions( settings );

            System.debug( '[ConvertAttachmentsToFilesSchedulable.execute] Executing: ' + context );
            System.debug( '[ConvertAttachmentsToFilesSchedulable.execute] Options: ' + options );
            System.debug( '[ConvertAttachmentsToFilesSchedulable.execute] Batch Size: ' + this.batchSize );

            ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable( options );

            Database.executeBatch( batchable, this.batchSize );

        } catch ( Exception e ) {

            Database.rollback( sp );

            ConvertAttachmentsToFilesLogger.log( context.getTriggerId(), e );

        } finally {

            ConvertAttachmentsToFilesLogger.sendApexExceptionEmailIfAnyErrorsSince( startTime );

        }

    }

}