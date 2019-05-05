/**
 * Created by rajesh.ramachandran on 4/12/2019.
 */

public with sharing class ExtractFieldPermissions {

    private String[] sPermNames = new String[]{};
    private String[] lsObjectNames = new String[]{'Account','Account_link__c','Contact','Opportunity','Lead__c','Case','Address__c','Vehicle__c','Vehicle_Relationship__c','Retail_task__c','Campaign','CampaignMember'};
    //private String[] lsObjectNames = new String[]{'Account'};
    private boolean isProfile = false;

    public ExtractFieldPermissions(String[] sPermNames, Boolean isProfile){
        this.sPermNames = sPermNames;
        this.isProfile = isProfile;
    }

    private String getReadableFieldsAsCSVString(){
        if (this.sPermNames == null || this.sPermNames.size() < 1){
            throw new WrongInputException('no Permissionset name provided as input');
        }
        String csvData = '';
        List<FieldPermissions> lsFP = new List<FieldPermissions>();
        if (this.isProfile == true){
            lsFP = [select field,parentid,parent.name,PermissionsEdit, PermissionsRead, SobjectType from FieldPermissions where parent.profile.name in :this.sPermNames and sobjecttype in :this.lsObjectNames and PermissionsRead = true];
        }
        else {
            lsFP = [select field,parentid,parent.name,PermissionsEdit, PermissionsRead, SobjectType from FieldPermissions where parentid in (select id from PermissionSet where name in :this.sPermNames) and sobjecttype in :this.lsObjectNames and PermissionsRead = true];
        }
        if (lsFP != null && lsFP.size() > 0){
            String header = 'Object,Field label,API Name,Data Type,Length,Controlling field,Market';
            String rowsdata = '';
            Set<String> setCompletedFields = new Set<String>();
            Map<String,Map<String,Schema.sObjectField>> mpObjToFieldsMap = getSchemaFieldMap(this.lsObjectNames);
            for (FieldPermissions fp : lsFP){
                Map<String,Schema.sObjectField> mpFieldMap = mpObjToFieldsMap.get(fp.sObjectType);
                List<String> rowdata = new List<String>();
                if (mpFieldMap != null && !setCompletedFields.contains(fp.field)){
                    String fldName = fp.field.split('\\.')[1];
                    Schema.sObjectField  fldDesc = mpFieldMap.get(fldName);
                    setCompletedFields.add(fp.field);
                    if (fldDesc == null){
                        String fldNameId = fldName + 'Id';
                        fldDesc = mpFieldMap.get(fldNameId);
                        if (fldDesc == null){
                            continue;
                        }
                    }
                    Schema.DescribeFieldResult dfr = fldDesc.getDescribe();
                    rowdata.add(fp.sObjectType);
                    rowdata.add(dfr.getLabel());
                    rowdata.add(dfr.getName());
                    rowdata.add(dfr.getType().name());
                    rowdata.add(String.valueOf(dfr.getLength()));
                    if (dfr.getController() != null){
                        rowdata.add(dfr.getController().getDescribe().getLabel());
                    }
                    else {
                        rowdata.add('');
                    }
                    rowdata.add('');//this is for market which has to be manually entered on basis of permissionsetName
                }
                String returnString = '';
                for(String newStr : rowdata) {
                    returnString += newStr.escapeCsv()+',';
                }
                if (!returnString.startsWith(',') && !returnString.startsWith('\n') && returnString.length() != 0 && returnString != ''){
                    rowsdata = rowsdata + returnString + '\n';
                }
            }
            csvData = header + '\n' + rowsdata;
        }
        return csvData;
    }


    private String getDependentPicklistValuesAsCSVString() {
        if (this.sPermNames == null || this.sPermNames.size() < 1) {
            throw new WrongInputException('no Permissionset name provided as input');
        }
        String csvData = '';

        return csvData;
    }
        public void sendEmailForReadableFields(String emailAddress){
        Messaging.EmailFileAttachment csvAttachment = new Messaging.EmailFileAttachment();
        String csvData = getReadableFieldsAsCSVString();
        Blob csvBlob = blob.valueOf(csvData);
        String csvName = 'FieldDetails.csv';
        csvAttachment.setFileName(csvName);
        csvAttachment.setBody(csvBlob);
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] {emailAddress};
        String subject = 'Requested field details is shared';
        email.setSubject(subject);
        email.setToAddresses(toAddresses);
        String sBody = 'Attached is the field informaion csv for the permissionsets - \n';
        for (String sPermName : this.sPermNames){
            sBody = sBody + sPermName + '\n';
        }
        email.setPlainTextBody(sBody);
        email.setFileAttachments(new Messaging.EmailFileAttachment[]{csvAttachment});
        Messaging.SendEmailResult[] r = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
    }

    private Map<String,Map<String,Schema.sObjectField>> getSchemaFieldMap(String[] objNames){

        Schema.DescribeSobjectResult[] results = Schema.describeSObjects(objNames);
        Map<String,Map<String,Schema.sObjectField>> mpObjToFieldsMap = new Map<String,Map<String,Schema.sObjectField>>();
        for(Schema.DescribeSobjectResult res : results){
            String sObjectName = res.getName();
            Map<String,Schema.sobjectField> fieldsMap = res.fields.getMap();
            mpObjToFieldsMap.put(sObjectName,fieldsMap);
        }
        return mpObjToFieldsMap;
    }


    private class WrongInputException extends  Exception {}



}