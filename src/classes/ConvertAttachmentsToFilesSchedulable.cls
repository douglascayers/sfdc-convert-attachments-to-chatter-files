public class ConvertAttachmentsToFilesSchedulable implements Schedulable {

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