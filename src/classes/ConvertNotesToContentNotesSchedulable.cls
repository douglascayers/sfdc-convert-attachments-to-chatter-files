public class ConvertNotesToContentNotesSchedulable implements Schedulable {

    private ConvertNotesToContentNotesOptions options { get; set; }

    private Integer batchSize { get; set; }

    public ConvertNotesToContentNotesSchedulable() {
        this( 200 );
    }

    public ConvertNotesToContentNotesSchedulable( Integer batchSize ) {
        this( batchSize, new ConvertNotesToContentNotesOptions() );
    }

    public ConvertNotesToContentNotesSchedulable( Integer batchSize, ConvertNotesToContentNotesOptions options ) {
        this.batchSize = batchSize;
        this.options = options;
    }

    public void execute( SchedulableContext context ) {

        System.debug( '[ConvertNotesToContentNotesSchedulable.execute] Executing: ' + context );
        System.debug( '[ConvertNotesToContentNotesSchedulable.execute] Options: ' + this.options );
        System.debug( '[ConvertNotesToContentNotesSchedulable.execute] Batch Size: ' + this.batchSize );

        ConvertNotesToContentNotesBatchable batchable = new ConvertNotesToContentNotesBatchable( this.options );

        Database.executeBatch( batchable, this.batchSize );

    }

}