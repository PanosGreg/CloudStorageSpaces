$class = @'
using System;

namespace IDBMod {
    public class Operation {

        public string   Executor;
        public string   Action;
        public string   TargetName;
        public string   TargetVersion;
        public string   Log;
        public DateTime Date {get; private set;}

        public Operation() { Date = DateTime.Now;}
        public Operation(string Executor, string Action) {
            this.Executor      = Executor;
            this.Action        = Action;
            this.Date          = DateTime.Now;
        } //constructor
    } //class operation
} //namespace
'@

Add-Type -TypeDefinition $class

# now set the default view of this instance
$obj  = [IDBMod.Operation]::new('aaa','bbb')
$Def  = [string[]]('Date','Action','Executor','Log') # <-- must give type
$ddps = [Management.Automation.PSPropertySet]::new("DefaultDisplayPropertySet",$Def)
$pssm = [Management.Automation.PSMemberInfo[]]@($ddps)
$obj | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $pssm