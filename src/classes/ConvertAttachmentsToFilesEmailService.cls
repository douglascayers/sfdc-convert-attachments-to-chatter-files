public class ConvertAttachmentsToFilesEmailService {

    // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_forcecom_email_outbound.htm

    public static void sendEmail( List<String> recipients, List<ConvertAttachmentsToFilesService.ConversionResult> conversionResults ) {

        // First, reserve email capacity for the current Apex transaction to ensure
        // that we won't exceed our daily email limits when sending email after
        // the current transaction is committed.
        Messaging.reserveSingleEmailCapacity( recipients.size() );

        Messaging.SingleEmailMessage emailMessage = new Messaging.SingleEmailMessage();
        emailMessage.setToAddresses( recipients );
        emailMessage.setSubject( 'Convert Attachments to Files Results' );
        emailMessage.setHtmlBody( buildHtmlBody( conversionResults ) );

        Messaging.sendEmail( new Messaging.Email[] { emailMessage } );

    }

    private static String buildHtmlBody( List<ConvertAttachmentsToFilesService.ConversionResult> conversionResults ) {

        String baseUrl = URL.getSalesforceBaseUrl().toExternalForm() + '/';

        String html = '';

        html += '<table border="1" cellspacing="3" cellpadding="3">' +
                    '<tr>' +
                        '<th>Success</th>' +
                        '<th>Attachment ID</th>' +
                        '<th>Content Version ID</th>' +
                        '<th>Message</th>' +
                    '</tr>';

        for ( ConvertAttachmentsToFilesService.ConversionResult result : conversionResults ) {
            html +=
                '<tr>' +
                    '<td>' + buildHtmlSuccess( result.success ) + '</td>' +
                    '<td>' + buildHtmlLink( result.attachmentId, baseUrl + defaultIfBlank( result.attachmentId ) ) + '</td>' +
                    '<td>' + buildHtmlLink( result.contentVersionId, baseUrl + defaultIfBlank( result.contentVersionId ) ) + '</td>' +
                    '<td>' + defaultIfBlank( result.message ) + '</td>' +
                '</tr>';
        }

        html += '</table>';

        return html;
    }

    private static String buildHtmlSuccess( Boolean success ) {

        String html = '';

        if ( success ) {
            html = '<div style="background-color:#00cc00; text-align:center">' + success + '</div>';
        } else {
            html = '<div style="background-color:#ff0000; text-align:center">' + success + '</div>';
        }

        return html;
    }

    private static String buildHtmlLink( String text, String link ) {
        return '<a href="' + link + '">' + defaultIfBlank( text ) + '</a>';
    }

    private static String defaultIfBlank( String text ) {
        return defaultIfBlank( text, '' );
    }

    private static String defaultIfBlank( String text, String defaultText ) {
        return ( String.isBlank( text ) ? defaultText : text );
    }

}