public with sharing class ConvertAttachmentsRunOnceController {

    public ConvertAttachmentsToFilesOptions options { get; set; }

    public String parentIdsCsv { get; set; }

    public Integer batchSize { get; set; }

    public String message { get; set; }

    public Boolean success { get; set; }

    public ConvertAttachmentsRunOnceController() {
        this.options = new ConvertAttachmentsToFilesOptions( Convert_Attachments_to_Files_Settings__c.getInstance() );
        this.batchSize = 200;
    }

    public void submitJob() {

        try {

            Set<ID> parentIds = new Set<ID>();

            for ( String parentId : this.parentIdsCsv.split( ',' ) ) {
                if ( String.isNotBlank( parentId ) ) {
                    parentIds.add( parentId.trim() );
                }
            }

            if ( !parentIds.isEmpty() ) {
                this.options.parentIds = parentIds;
            }

            System.debug( 'submitting one-time conversion job: ' + this.options );

            ConvertAttachmentsToFilesBatchable job = new ConvertAttachmentsToFilesBatchable( this.options );

            Database.executeBatch( job, this.batchSize );

            this.message = 'Conversion batch job submitted';
            this.success = true;

        } catch ( Exception e ) {

            System.debug( LoggingLevel.ERROR, e.getMessage() + ' : ' + e.getStackTraceString() );

            this.message = e.getMessage();
            this.success = false;

        }

    }

}