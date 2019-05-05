/**
 * Created by rajesh.ramachandran on 4/29/2019.
 */

public with sharing class ExtractMarketPicklistValues {

    private String csvHeader = 'Object, Field, Picklist Value, Market';
    public String[] lsObjectNames = new String[]{'Account','Account_link__c','Contact','Opportunity','Lead__c','Case','Address__c','Vehicle__c','Vehicle_Relationship__c','Retail_task__c','Campaign','CampaignMember'};

    public void sendEmailForDependentFields(String emailAddress){
        Messaging.EmailFileAttachment csvAttachment = new Messaging.EmailFileAttachment();
        String csvData = csvHeader + '\n';
        for (String sObjName : lsObjectNames){
            csvData = csvData + getMarketDependentFields(sObjName);
        }
        Blob csvBlob = blob.valueOf(csvData);
        String csvName = 'DependentPicklistDetails.csv';
        csvAttachment.setFileName(csvName);
        csvAttachment.setBody(csvBlob);
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] {emailAddress};
        String subject = 'Requested market dependent details is shared';
        email.setSubject(subject);
        email.setToAddresses(toAddresses);
        String sBody = 'Attached is the market dependent picklist csv for the objects - \n';
        for (String sObjName : this.lsObjectNames){
            sBody = sBody + sObjName + '\n';
        }
        email.setPlainTextBody(sBody);
        email.setFileAttachments(new Messaging.EmailFileAttachment[]{csvAttachment});
        Messaging.SendEmailResult[] r = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
    }

    private String getMarketDependentFields ( String sObjectName ){
        String rowsdata = '';
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(sObjectName).getDescribe().fields.getMap();
        for (String fldString : fieldMap.keySet()){
            Schema.DescribeFieldResult fldToken = fieldMap.get(fldString).getDescribe();
            if (fldToken.getType() == Schema.DisplayType.PICKLIST){
                if (fldToken.getController() != null && fldToken.getController().getDescribe().getLabel() == 'Market'){
                    //get picklist values where it is a dependent picklist on Market
                    String fldLabel = fieldMap.get(fldString).getDescribe().getLabel();
                    Map<String, List<Object>> sRetDependentMap = getDependentPicklistValues(fieldMap.get(fldString));
                    for (String sVal : sRetDependentMap.keySet()){
                        List<String> rowData = new List<String>();
                        rowData.add(sObjectName);
                        rowData.add(fldLabel);
                        rowData.add(sVal);
                        String sMarket = '';
                        for (Object sDepVal : sRetDependentMap.get(sVal)){
                            sMarket = sMarket + String.valueOf(sDepVal) + ' || ';
                            }
                        rowData.add(String.valueOf(sMarket));
                        String returnString = '';
                        for(String newStr : rowdata) {
                            returnString += newStr.escapeCsv()+',';
                        }
                        if (!returnString.startsWith(',') && !returnString.startsWith('\n') && returnString.length() != 0 && returnString != ''){
                            system.debug(returnString);
                            rowsdata = rowsdata + returnString + '\n';
                        }
                    }
                }
                else {
                    for ( Schema.PicklistEntry entry : fldToken.getPicklistValues() ){
                        if ( entry.isActive() ){
                            String fldLabel = fieldMap.get(fldString).getDescribe().getLabel();
                            List<String> rowData = new List<String>();
                            rowData.add(sObjectName);
                            rowData.add(fldLabel);
                            rowData.add(entry.getLabel());
                            String sMarket = 'ALL';
                            rowData.add(String.valueOf(sMarket));
                            String returnString = '';
                            for(String newStr : rowdata) {
                                returnString += newStr.escapeCsv()+',';
                            }
                            if (!returnString.startsWith(',') && !returnString.startsWith('\n') && returnString.length() != 0 && returnString != ''){
                                system.debug(returnString);
                                rowsdata = rowsdata + returnString + '\n';
                            }
                        }
                    }
                }
            }
        }
        return(rowsdata);
    }

    /*private String getMarketDependentFields ( String sObjectName ){
        String rowsdata = '';
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(sObjectName).getDescribe().fields.getMap();
        for (String fldString : fieldMap.keySet()){
            Schema.DescribeFieldResult fldToken = fieldMap.get(fldString).getDescribe();
            if (fldToken.getController() != null && fldToken.getController().getDescribe().getLabel() == 'Market'){
                String fldLabel = fieldMap.get(fldString).getDescribe().getLabel();
                Map<Object, List<String>> sRetDependentMap = getDependentPicklistValues(fieldMap.get(fldString));
                for (Object sVal : sRetDependentMap.keySet()){
                    //system.debug(fldLabel);
                    //system.debug(sVal);
                    //system.debug(sRetDependentMap.get(sVal));
                    for (String sDepVal : sRetDependentMap.get(sVal)){
                        List<String> rowData = new List<String>();
                        rowData.add(sObjectName);
                        rowData.add(fldLabel);
                        rowData.add(String.valueOf(sVal));
                        rowData.add(sDepVal);
                        String returnString = '';
                        for(String newStr : rowdata) {
                            returnString += newStr.escapeCsv()+',';
                        }
                        if (!returnString.startsWith(',') && !returnString.startsWith('\n') && returnString.length() != 0 && returnString != ''){
                            system.debug(returnString);
                            rowsdata = rowsdata + returnString + '\n';
                        }
                    }
                }
            }
        }
        return(rowsdata);

    }
    */
    //Code from GlynAtSlalom that uses validFor value and base64 index based logic to identify dependent picklist values
    private static Map<String,List<Object>> getDependentPicklistValues( Schema.sObjectField dependToken )
    {
        Schema.DescribeFieldResult depend = dependToken.getDescribe();
        Schema.sObjectField controlToken = depend.getController();
        if ( controlToken == null ) return null;
        Schema.DescribeFieldResult control = controlToken.getDescribe();
        List<Schema.PicklistEntry> controlEntries = ( control.getType() == Schema.DisplayType.Boolean? null : control.getPicklistValues());

        String base64map = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
        Map<String,List<Object>> dependentPicklistValues = new Map<String,List<Object>>();
        for ( Schema.PicklistEntry entry : depend.getPicklistValues() ){
            if ( entry.isActive() )
            {
                List<String> base64chars = String.valueOf(((Map<String,Object>) JSON.deserializeUntyped( JSON.serialize( entry ))).get('validFor')).split( '' );
                for ( Integer index = 0; index < (controlEntries != null ? controlEntries.size() : 2); index++ )
                {
                    Object controlValue = (controlEntries == null? (Object) (index == 1): (Object) (controlEntries[ index ].isActive() ? controlEntries[ index ].getLabel() : null));
                    Integer bitIndex = index / 6;
                    Integer bitShift = 5 - Math.mod( index, 6 );
                 //   if (base64chars.size() < (bitIndex + 2))
                 //       continue;
                    try{
                        if ( (controlValue == null) ||  ((base64map.indexOf( base64chars[ bitIndex ] ) & (1 << bitShift)) == 0) )
                            continue;
                    }
                    catch(Exception e){
                        system.debug(bitIndex + '++++' + bitShift);
                        continue;
                    }
                    if ( !dependentPicklistValues.containsKey( entry.getLabel() ))
                    {
                        dependentPicklistValues.put( entry.getLabel(), new List<Object>() );
                    }
                    dependentPicklistValues.get( entry.getLabel() ).add( controlValue );
                }
            }
        }
        return dependentPicklistValues;
    }


}