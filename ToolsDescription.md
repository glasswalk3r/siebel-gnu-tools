

# Introduction #

There are several programs available when downloading Siebel GNU Tools. Some of those tools are multi-platform others are for a specific OS.

## Compile SRF ##

This Windows Powershell 2 script will:

  1. stop the related Windows Services of a Siebel Server
  1. create a backup of a previous SRF
  1. compiled a full new SRF in the language of choice
  1. restart the Siebel services

The script has the following features:

  * uses a external configuration (XML file)
  * can stop/restart an arbitrary number of Windows Services
  * services will be restarted in the reverse order that they were stopped, which means

Future release will include:

  * logging with Log4net
  * sending e-mails

The script requires the availability of the log4net.dll file as configured in the XML file. More information about the Log4net project can be found at http://logging.apache.org/log4net/index.html

  * Language code = Windows Powershell version 2
  * Runs at = Any MS Windows version that supports Powershell version 2

## Siebel defrag ##

This script will stop the Siebel Services in a server and start the defrag.exe program to defragment the server disks. Once the defragmentation is finished, the services will be turned on again.

This script is specially useful for Siebel development servers.

  * Language code = Windows Powershell version 2
  * Runs at = Any MS Windows version that supports Powershell version 2

## Server manager 2 ##

This script is a replacement for the srvrmgr.exe: it uses the Windows Crypto API to cryptographic the login and password used to access a given Siebel Enterprise and execute arbitrarily commands. See http://search.cpan.org/~lmasara/Win32-CryptData-0.02/CryptData.pm for more information about this process. Please check the command line help for more information.

This program is useful to run commands like invoking Workflow Process, an EIM data load or any other command that srvrmgr.exe supports.

  * Language code = Perl.
  * Runs at = Any MS Windows version that supports Perl and Crypto API.

## Transaction Router Performance reporter ##

When trying to identify performance issues with Siebel Transaction Router, it is possible to change the log levels of the component to generate performance information. This information can lead to huge log files (measured in Mb or even Gb) that are just too hard to have information checked with a common text editor.

This program was created to parse those log files, looking for performance information and generating two line charts:

  1. one with information about time taken to execute tasks in a given timestamp
  1. one with information about the number of operations in a given timestamp

Each point in those charts means the highest value found in that timestamp (not all values will be show in the chart). Here is an example:

![http://siebel-gnu-tools.googlecode.com/files/times_2011-10-14.png](http://siebel-gnu-tools.googlecode.com/files/times_2011-10-14.png)

When the amount of information is too large to fit in a chart, the program can accept a parameter to show only N highest values found in the log files. Please check the command line help for more information.

Additionally, the program will generate a histogram with the total time expend for each one of the nodes processed in a given timestamp. Here is an example:

![http://siebel-gnu-tools.googlecode.com/files/total_time_2011-10-15.png](http://siebel-gnu-tools.googlecode.com/files/total_time_2011-10-15.png)

With this information, the user can have a hint of when the component started taking too much time to route information and/or have too much operations to execute and compare with measures taken from the servers (like CPU, memory and network usage by time).

If the generated graphics are not enough for the analysis, the program has an additional command line option `--export` that will create two CSV files with all the times and operations data found in the log files. Additionally, the program will include the Total Time and TS Time from the operations information in the times CSV file.

With those files is just a matter to import the CSV in your preferred program like Microsoft Excel or [R](http://www.r-project.org/) and generate the graphics in any way you need. Below is an example using R:

![http://siebel-gnu-tools.googlecode.com/files/exported_R.png](http://siebel-gnu-tools.googlecode.com/files/exported_R.png)

**Caution:** beware of new line characters differences between different operational systems! For example, if the log file were generated in a Microsoft Windows, they will have CRLF to define new lines. In any other UNIX the new lines are identified by LF only. While Perl can identify which line character identifies a new line in the operational system it is being executed, perl\_txnrouter will not note those differences and the results generated might contain errors. Be sure to convert those new line characters before processing the logs!

  * Language code = Perl
  * Runs at = any OS that supports Perl

## Dx reporter ##

Unfortunately some bad users of Siebel Remote do not synchronize their client at regular times (for example, once in a day). Some of those users can get weeks or even months to do that, which is bad for everybody since:

  * the Siebel Remote user will take an unnecessary long time to download all the DX files (depending on several conditions, it will be faster to re-extract a new local database).
  * if the file system used in the Siebel Remote Server is NTFS, the operational system (and thus Siebel itself) will suffer to deal with all the DX files due NTFS fragmentation of folder's index information (more details [here](http://stackoverflow.com/questions/197162/ntfs-performance-and-large-volumes-of-files-and-directories).)
  * waste of Siebel Server file system storage space.

The Dx reporter helps with that: this Powershell will connect to the Siebel database with OLEDB, create a list of all active nodes in the Siebel Remote and counting how many DX files are waiting in the _outbox_ folder be synchronized, generating a spreadsheet like window (or just plain text) as a report with the node name, user associated, primary held position, last synchronization session and the total amount of DX files read. Here is an example of report:

![http://siebel-gnu-tools.googlecode.com/files/%24returnData%20%20Select-Object%20%20-ExcludeProperty%20RunspaceId%20%20out-gridview_2012-07-20_11-00-40.png](http://siebel-gnu-tools.googlecode.com/files/%24returnData%20%20Select-Object%20%20-ExcludeProperty%20RunspaceId%20%20out-gridview_2012-07-20_11-00-40.png)

Dx Reporter is capable to count the DX files in parallel (see the command line option `-maxThreads` for more information), speeding up the process as much is possible to create the report. Here is a screen-shot as example for limiting the program to use only 10 current "threads":

![http://siebel-gnu-tools.googlecode.com/files/Administrator%20CWINDOWSsystem32WindowsPowerShellv1.0powershell.png](http://siebel-gnu-tools.googlecode.com/files/Administrator%20CWINDOWSsystem32WindowsPowerShellv1.0powershell.png)

  * Language code = Windows Powershell version 2
  * Runs at = Any MS Windows version that supports Powershell version 2

## Siebel local data base dumper ##

This tool enables copying a Siebel local database (a SQL Anywhere database) content to a SQLite database file.

All content (schema, indexes and data) is converted and recreated at the SQLite database.

This is very useful if you need to have the data available in other platforms than those supported by Siebel or don't have the proper driver (and license) of Sybase SQL Anywhere. Besides that, installing SQLite is much more easier than SQL Anywhere nowadays.

Here is an screen-shot of the tool in action:

![http://siebel-gnu-tools.googlecode.com/files/dumper.png](http://siebel-gnu-tools.googlecode.com/files/dumper.png)

The program just asks for some command lines parameters (see -h for online help) and starts doing the process. The copy occurs generally very fast. As an example, I was able to dump a Siebel local database to a SQLite in ~760 seconds by using a Dell notebook with the following configuration:
  * Intel Core i5-3360 2.80Ghz
  * 3,4Gb memory
  * Windows 7 Enterprise Service pack 1
  * McCafee Endpoint Encryption (total)

Considering that Endpoint Encryption is really an I/O performance hog, the copy occurs very fast.

You can more implementations details of Siebel local database dumper at http://slashlogging.blogspot.com/2013/04/improving-bulk-inserts-on-sqlite.html.

## Devel::AssertOS::OSFeatures::SupportsSiebel ##

This is a generic Perl module that is useful for developers that want to publish any code intended to work with Siebel CRM system.

By simply importing this module in your Perl code, it will check if the running system is one of those OS supported by Siebel (versions will not be checked at this time).

This is quite useful to validate software configuration and if the author wants to make the code available at [CPAN](http://search.cpan.org).

Devel::AssertOS::OSFeatures::SupportsSiebel is also available at [Comprehensive Perl Archive Network](http://search.cpan.org) (CPAN) as well.

# Setup instructions #

For Powershell programs, just unpacking the tarball will be enough. Of course, the scripts will need their respective interpreter to be able to run (Perl or Windows Powershell).

Perl itself can be download from http://www.perl.org/get.html. Windows Powershell version 2 can be downloaded from http://www.microsoft.com/en-us/download/.

## Perl programs ##

The Perl program have modules dependencies that must be resolved before the programs can be executed. There are several ways to install Perl modules:

  1. executing the Makefile.PL
  1. using CPAN shell
  1. using PPM (for ActivePerl only)
  1. resolving the dependencies manually

The last method should be the most complicated one, since a module dependency could have more dependencies by it own, leading to even more dependencies to resolve. The methods 2 and 3 should be the preferred ones. For instructions to run then, please check the corresponding documentation of the Perl distribution chosen.

Method 1 involves executing:

```
perl Makefile.PL
make
make install
```

This requires having the make program (or any other compatible program like nmake) to read the Makefile generated by Makefile.PL. The CPAN shell has an interesting feature to execute those steps automatically, even resolving the dependencies as necessary. See http://search.cpan.org/~andk/CPAN-1.9800/lib/CPAN.pm#Integrating_local_directories for more information.

Strawberry Perl already comes with a make program available, so it is highly recommended.