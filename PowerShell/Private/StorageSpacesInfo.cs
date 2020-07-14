using System;
using System.Diagnostics;
using System.ComponentModel;   // <-- this is required for the Description attribute in Enums

namespace CloudSS {

    public class PSProperties {
        public string   PSComputerName {get; private set;}
        public string   PSUserName     {get; private set;}
        public DateTime PSDateTime     {get; private set;}
        public int      PSProcessID    {get; private set;}
        public string   PSProcessName  {get; private set;}
        public string   PSProcessPath  {get; private set;}

        public PSProperties() {
            Process proc   = Process.GetCurrentProcess();
            string dom     = Environment.GetEnvironmentVariable("UserDomain");
            string usr     = Environment.GetEnvironmentVariable("UserName");
            PSComputerName = Environment.GetEnvironmentVariable("ComputerName");
            PSUserName     = String.Format("{0}\\{1}",dom,usr);
            PSDateTime     = DateTime.Now;
            PSProcessID    = proc.Id;
            PSProcessName  = proc.ProcessName;
            PSProcessPath  = proc.MainModule.FileName;
        } //constructor
    } //PSProperties class

    public class ExpandInfo {
        public Int64 SizePerExpansion;
        public int   ExpasionsLeft;    // this comes from Azure (outside of the VM), cause it needs the MaxDiskCount
        public Int64 PotentialMaxSize; // this comes from Azure (outside of the VM), cause it needs the MaxDiskCount
        public int   ExpansionsUsed;

        public ExpandInfo() {}
    } //ExpandInfo class

    public class DefaultDisk {     // all properties of this object come from Azure (outside of the VM)
        public string  Prefix;
        public SkuName SkuName;
        public int     DiskSizeGB;
        public string  Location;

        public DefaultDisk() {}
    } //DefaultDisk class

    public enum SkuName {
        [Description("MediaType=HDD")]
        Standard_LRS    = 11,            // Azure
        [Description("MediaType=SSD")]
        Premium_LRS     = 12,            // Azure
        [Description("MediaType=SSD")]
        StandardSSD_LRS = 13,            // Azure
        [Description("MediaType=NVMe")]
        UltraSSD_LRS    = 14,            // Azure
        [Description("MediaType=HDD")]
        standard        = 21,            // AWS (legacy)
        [Description("MediaType=SSD")]
        gp2             = 22,            // AWS
        [Description("MediaType=SSD")]
        io1             = 23,            // AWS
        [Description("MediaType=HDD")]
        sc1             = 24,            // AWS
        [Description("MediaType=HDD")]
        st1             = 25             // AWS
//  "standard", "gp2", "io1", "sc1" or "st1"

    } //SkuName enum

    public class PhysicalDisks {
        public string    FriendlyName;
        public Int64     Size;
        public MediaType MediaType;
        public int       Lun;
        public bool      InStorageSpace;

        public PhysicalDisks() {}
    } //PysicalDisks class

    public enum MediaType {
        HDD  = 1,
        SSD  = 2,
        NVMe = 3,
        SCM  = 4     // Storage Class Memory ie.NVDIMMs
    } //MediaType enum

    public class VirtualDisk {
        public char              Letter;
        public string            Name;
        public string            SizeTotal;          // this is string via ConvertTo-PrettyCapacity
        public string            SizeRemaining;      // this is string via ConvertTo-PrettyCapacity
        public string            SizeUsed;           // this is string via ConvertTo-PrettyCapacity
        public string            PercentUsed;        // this is string via ConvertTo-PrettyPercentage
        public string            PercentRemaining;   // this is string via ConvertTo-PrettyPercentage
        public ResiliencySetting ResiliencySetting;
        public FileSystem        FileSystem;

        public VirtualDisk() {}
    } //VirtualDisk class

    public enum ResiliencySetting {
        Simple = 1,
        Mirror = 2,
        Parity = 3 
    }

    public enum FileSystem {
        NTFS = 1,
        ReFS = 2
    }

    public class NumberOf {
        public int ColumnsInSS;
        public int DisksInSS;
        public int MaxDisksInVM;        // this comes from Azure (outside of the VM)
        public int AttachedDisksInVM;   // this comes from Azure (outside of the VM)
        public int AvailableDisksInVM;  // this comes from Azure (outside of the VM)

        public NumberOf() {}
    } //NumberOf class

    public class StorageSpacesInfo {
        public PSProperties    PSProperties {get; private set;}
        public ExpandInfo      ExpandInfo;
        public DefaultDisk     DefaultDisk;
        public PhysicalDisks[] PhysicalDisks;
        public VirtualDisk     VirtualDisk;
        public NumberOf        NumberOf;

        public StorageSpacesInfo() {
            PSProperties       = new PSProperties();
            this.ExpandInfo    = new ExpandInfo();
            this.DefaultDisk   = new DefaultDisk();
            this.VirtualDisk   = new VirtualDisk();
            this.PhysicalDisks = new PhysicalDisks[] {};
            this.NumberOf      = new NumberOf();
        } //constructor
    } //StorageSpacesInfo class
} //namespace


/*
IDEA:
add a method that will write a csv file based on the data from the current class instance

if you have an array of servers, then you have a number of these objects
and hence if you run a foreach with this method, you'll have a number of csv files

these csv files can then be merged into one, and could be used in Power BI to give us
a nice report with charts and dynamic filtering.

All you need is a Power BI template file which will be used to load the csv's and show 
the data.

since these are not real-time data, but rather static, since we are talking about number
of disks in a bunch of servers, which is something we don't change much, a static Power BI
report makes sense, as opposed to a dashboard page in grafana. Since grafana is more for 
real-time (or almost real-time) changing data.

This Power BI report could show, the current disk sizes, the max possible for each server,
the number of disks occupied and the max number of disks supported per vm.
Or maybe even per SQL cluster, since each SQL Availability Group is comprised of identical servers.

So once the script runs to expand one or more servers, then it could create a csv file that will
be saved in an external location, like Amazon S3 or Azure Blob, and then merge all those CSV from
that folder/container into a single CSV.
Then all you need to do is open the appropriate Power BI file and load that CSV, and you've got
the report.


*/



/*
PS function: if input object pstypename is 'mytypename'
then go ahead and parse it

do a few get.enumerator() on the hashtables and add the contents
to the custom object/class

*/