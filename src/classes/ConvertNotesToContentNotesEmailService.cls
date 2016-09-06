public class ConvertNotesToContentNotesEmailService {

    // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_forcecom_email_outbound.htm

    public static void sendEmail( List<String> recipients, List<ConvertNotesToContentNotesService.ConversionResult> conversionResults ) {

        // First, reserve email capacity for the current Apex transaction to ensure
        // that we won't exceed our daily email limits when sending email after
        // the current transaction is committed.
        Messaging.reserveSingleEmailCapacity( recipients.size() );

        Messaging.SingleEmailMessage emailMessage = new Messaging.SingleEmailMessage();
        emailMessage.setToAddresses( recipients );
        emailMessage.setSubject( 'Convert Notes to ContentNotes Results' );
        emailMessage.setHtmlBody( buildHtmlBody( conversionResults ) );

        if ( !Test.isRunningTest() ) {
            Messaging.sendEmail( new Messaging.Email[] { emailMessage } );
        }

    }

    private static String buildHtmlBody( List<ConvertNotesToContentNotesService.ConversionResult> conversionResults ) {

        List<ConvertNotesToContentNotesService.ConversionResult> successResults = new List<ConvertNotesToContentNotesService.ConversionResult>();
        List<ConvertNotesToContentNotesService.ConversionResult> failureResults = new List<ConvertNotesToContentNotesService.ConversionResult>();

        for ( ConvertNotesToContentNotesService.ConversionResult result : conversionResults ) {
            if ( result.success ) {
                successResults.add( result );
            } else {
                failureResults.add( result );
            }
        }

        String html = '';

        html += '<table border="1" cellspacing="3" cellpadding="3">' +
                    '<tr>' +
                        '<th>Success</th>' +
                        '<th>Note ID</th>' +
                        '<th>Content Note ID</th>' +
                        '<th>Message</th>' +
                    '</tr>';

        html += buildHtmlTableRows( failureResults );
        html += buildHtmlTableRows( successResults );

        html += '</table>';

        return html;
    }

    private static String buildHtmlTableRows( List<ConvertNotesToContentNotesService.ConversionResult> conversionResults ) {

        String html = '';

        String baseUrl = URL.getSalesforceBaseUrl().toExternalForm() + '/';

        for ( ConvertNotesToContentNotesService.ConversionResult result : conversionResults ) {
            html +=
                '<tr>' +
                    '<td>' + buildHtmlSuccess( result.success ) + '</td>' +
                    '<td>' + buildHtmlLink( result.noteId, baseUrl + defaultIfBlank( result.noteId ) ) + '</td>' +
                    '<td>' + buildHtmlLink( result.contentNoteId, baseUrl + defaultIfBlank( result.contentNoteId ) ) + '</td>' +
                    '<td>' + defaultIfBlank( result.message ) + '</td>' +
                '</tr>';
        }

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