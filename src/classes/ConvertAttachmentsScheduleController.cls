public with sharing class ConvertAttachmentsScheduleController {

    public ScheduleRequest request { get; set; }

    public Boolean enableTrigger { get; set; }

    public String message { get; set; }

    public Boolean success { get; set; }

    public ConvertAttachmentsScheduleController() {
        this.request = new ScheduleRequest();
        this.enableTrigger = Convert_Attachments_to_Files_Settings__c.getInstance().Convert_in_Near_Real_Time__c;
    }

    public void save() {



    }

    public class ScheduleRequest {

        public Boolean sunday { get; set; }
        public Boolean monday { get; set; }
        public Boolean tuesday { get; set; }
        public Boolean wednesday { get; set; }
        public Boolean thursday { get; set; }
        public Boolean friday { get; set; }
        public Boolean saturday { get; set; }

        public Integer timeOfDay { get; set; } // 0-23 military time

        public ScheduleRequest() {
            this.timeOfDay = 0;
        }

    }

}