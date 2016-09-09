/**
 * Enqueues a job to convert the attachments into files.
 */
trigger ConvertNotesToContentNotesTrigger on Note ( after insert ) {

    Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getInstance();

    if ( settings.convert_in_near_real_time__c ) {

        ConvertNotesToContentNotesQueueable queueable = new ConvertNotesToContentNotesQueueable(
            Trigger.newMap.keySet(),
            new ConvertNotesToContentNotesOptions( settings )
        );

        System.enqueueJob( queueable );

    }

}