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

        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.allowFieldTruncation = true;

        Convert_Attachments_to_Files_Log__c log = new Convert_Attachments_to_Files_Log__c(
            job_id__c = jobId,
            summary__c = e.getMessage(),
            detail__c = e.getStackTraceString()
        );

        Database.insert( log, dmo );

    }

    /**
     * Designed to be called after conversion job has run to log any errors.
     */
    public static void log( ID jobId, List<ConvertAttachmentsToFilesService.ConversionResult> results ) {

        List<Convert_Attachments_to_Files_Log__c> logs = new List<Convert_Attachments_to_Files_Log__c>();
        Integer maxLength = Convert_Attachments_to_Files_Log__c.Summary__c.getDescribe().getLength();

        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.allowFieldTruncation = true;

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
            Database.insert( logs, dmo );
        }

    }

    /**
     * Checks if any log records have been created since the job started.
     * If yes then sends an email to any Salesforce users configured for Apex Exception Email.
     */
    public static void sendApexExceptionEmailIfAnyErrorsSince( ID jobId ) {

        AsyncApexJob job = [ SELECT id, createdDate FROM AsyncApexJob WHERE id = :jobId ];

        sendApexExceptionEmailIfAnyErrorsSince( job.createdDate );

    }

    /**
     * Checks if any log records have been created since the given date/time.
     * If yes then sends an email to any Salesforce users configured for Apex Exception Email.
     */
    public static void sendApexExceptionEmailIfAnyErrorsSince( DateTime sinceDateTime ) {

        Integer count = [ SELECT count() FROM Convert_Attachments_to_Files_Log__c WHERE createdDate >= :sinceDateTime ];

        if ( count > 0 ) {

            List<ID> usersToNotify = new List<ID>();

            for ( ApexEmailNotification notif : [ SELECT userId FROM ApexEmailNotification WHERE userId != null LIMIT 100 ] ) {
                usersToNotify.add( notif.userId );
            }

            if ( usersToNotify.size() > 0 ) {

                Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
                message.toAddresses = usersToNotify;
                message.subject = 'Errors: Convert Attachments to Enhanced Attachments';
                message.plainTextBody = 'Errors have occurred. Please review the log records for more details ' +
                                        URL.getSalesforceBaseURL().toExternalForm() + '/' + Convert_Attachments_to_Files_Log__c.sObjectType.getDescribe().getKeyPrefix();

                Messaging.sendEmail( new Messaging.SingleEmailMessage[] { message } );

            }

        }

    }

}