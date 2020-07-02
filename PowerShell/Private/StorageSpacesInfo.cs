using System;

namespace AzureSS {
    public class StorageSpaceInfo {

        public string   PSComputerName;
        public string   PSUserName;
        public DateTime PSDateTime {get; private set;}
        public int      PSProcessID; 
        public string   PSProcessName; 
        public string   PSProcessPath; 
        public string   Action;
        public string   TargetName;
        public string   TargetVersion;
        public string   Log;
        

        public Operation() { Date = DateTime.Now;}
        public Operation(string Executor, string Action) {
            this.Executor      = Executor;
            this.Action        = Action;
            this.Date          = DateTime.Now;
        } //constructor
    } //class operation
} //namespace