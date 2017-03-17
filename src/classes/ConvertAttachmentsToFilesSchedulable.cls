/**
 * Designed for scheduling periodic job to perform batch conversion of attachments.
 *
 * For a more real-time or near real-time conversion of attachments to files, consider these other options:
 *      1. In Setup | Customize | Salesforce Files | Settings | General Settings,
 *         enable the options "Files uploaded to the Attachments related list on records are uploaded as Salesforce Files".
 *      2. Use the ConvertAttachmentsToFilesTrigger by enabling custom setting
 *         Convert_Attachments_to_Files_Settings.Convert_in_Near_Real_Time__c = true.
 */
public with sharing class ConvertAttachmentsToFilesSchedulable implements Schedulable {

    private ConvertAttachmentsToFilesOptions options { get; set; }

    private Integer batchSize { get; set; }

    public ConvertAttachmentsToFilesSchedulable() {
        this( 200 );
    }

    public ConvertAttachmentsToFilesSchedulable( Integer batchSize ) {
        this( batchSize, new ConvertAttachmentsToFilesOptions() );
    }

    public ConvertAttachmentsToFilesSchedulable( Integer batchSize, ConvertAttachmentsToFilesOptions options ) {
        this.batchSize = batchSize;
        this.options = options;
    }

    public void execute( SchedulableContext context ) {

        System.debug( '[ConvertAttachmentsToFilesSchedulable.execute] Executing: ' + context );
        System.debug( '[ConvertAttachmentsToFilesSchedulable.execute] Options: ' + this.options );
        System.debug( '[ConvertAttachmentsToFilesSchedulable.execute] Batch Size: ' + this.batchSize );

        ConvertAttachmentsToFilesBatchable batchable = new ConvertAttachmentsToFilesBatchable( this.options );

        Database.executeBatch( batchable, this.batchSize );

    }

}