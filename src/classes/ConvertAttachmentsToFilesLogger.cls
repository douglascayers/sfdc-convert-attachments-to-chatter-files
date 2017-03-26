/**
 * Developed by Doug Ayers (douglascayers.com)
 */
public with sharing class ConvertAttachmentsToFilesLogger {

    /**
     * Designed to be called once when exception is caught
     * during a batch or queued job conversion.
     */
    public static void log( Exception e ) {

        System.debug( LoggingLevel.ERROR, e.getMessage() + ' : ' + e.getStackTraceString() );

        Convert_Attachments_to_Files_Log__c log = new Convert_Attachments_to_Files_Log__c(
            summary__c = e.getMessage(),
            detail__c = e.getStackTraceString()
        );

        insert log;

    }

    /**
     * Designed to be called after conversion job has run to log any errors.
     */
    public static void log( List<ConvertAttachmentsToFilesService.ConversionResult> results ) {

        List<Convert_Attachments_to_Files_Log__c> logs = new List<Convert_Attachments_to_Files_Log__c>();
        Integer maxLength = Convert_Attachments_to_Files_Log__c.Summary__c.getDescribe().getLength();

        for ( ConvertAttachmentsToFilesService.ConversionResult result : results ) {
            if ( !result.success ) {
                logs.add( new Convert_Attachments_to_Files_Log__c(
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