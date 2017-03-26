/**
 * Developed by Doug Ayers (douglascayers.com)
 */
public with sharing class ConvertAttachmentsToFilesLogger {

    /**
     * Designed to be called once when exception is caught
     * during a batch or queued job conversion.
     */
    public static void log( ID jobId, Exception e ) {

        System.debug( LoggingLevel.ERROR, 'jobId: ' + jobId + ', error: ' + e.getMessage() + ' : ' + e.getStackTraceString() );

        Convert_Attachments_to_Files_Log__c log = new Convert_Attachments_to_Files_Log__c(
            job_id__c = jobId,
            summary__c = e.getMessage(),
            detail__c = e.getStackTraceString()
        );

        insert log;

    }

    /**
     * Designed to be called after conversion job has run to log any errors.
     */
    public static void log( ID jobId, List<ConvertAttachmentsToFilesService.ConversionResult> results ) {

        List<Convert_Attachments_to_Files_Log__c> logs = new List<Convert_Attachments_to_Files_Log__c>();
        Integer maxLength = Convert_Attachments_to_Files_Log__c.Summary__c.getDescribe().getLength();

        for ( ConvertAttachmentsToFilesService.ConversionResult result : results ) {

            if ( !result.success ) {

                System.debug( LoggingLevel.ERROR, 'jobId: ' + jobId + ', error: ' + result.message );

                logs.add( new Convert_Attachments_to_Files_Log__c(
                    job_id__c = jobId,
                    summary__c = result.message.abbreviate( maxLength ),
                    detail__c = result.message
                ));

            }

        }

        if ( logs.size() > 0 ) {
            insert logs;
        }

    }

}