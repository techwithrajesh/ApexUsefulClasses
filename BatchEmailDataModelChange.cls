public class BatchEmailDataModelChange implements Database.Batchable<sObject>, Schedulable{
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id,Action,CreatedBy.Name,CreatedDate,Display,Section FROM SetupAuditTrail where action in (\'createdCFCustom\',\'createdCF\',\'createdCFLookupCustom\',\'createdCFFormulaCustom\',\'createdCustEnt\',\'createdCustMdType\',\'changedCFTypeCustom\',\'changedCFCustom\',\'changedCustEntLabel\',\'changedCF\',\'changedCFType\',\'changedCFLength\') and createddate = last_n_days:7 order by createddate desc';
        system.debug(query);
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SetupAuditTrail> scope){
        system.debug(scope.size());
        Messaging.Singleemailmessage mail = new Messaging.Singleemailmessage();
        mail.setToAddresses(new String[] {'rajesh.ramachandran@infosys.com'});
        mail.setReplyTo('noreply@daimler.com');
        mail.setSubject('Data model changes this week in Asiadevin1');
        mail.setBccSender(false);
        mail.setUseSignature(false);
        String Body = 'In last 7 days the data model changes made in the org are mentioned below: \n';
        for (SetupAuditTrail sat : scope){
            body = body + sat.action + '||' + sat.section + '||' + sat.createddate + '||' + sat.display + '||' + '\n';
        }
        body = body + '\n Thanks, \n Rajesh Ramachandran.';
        mail.setPlainTextBody(body);
        system.debug('@@@@ sendEmail - mail : ' + mail);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }

    public void finish(Database.BatchableContext bc){
        system.debug('Executed batch job to check for data model changes');
    }

    public void execute(SchedulableContext ctx){
        BatchEmailDataModelChange bEDMC = new BatchEmailDataModelChange();
        Database.executeBatch(bEDMC);
    }
}