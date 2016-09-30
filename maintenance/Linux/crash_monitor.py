#!/usr/bin/env python

"""
Script to search for Siebel Server crash files and generate a report to help to identify the problem

If any is found, it will execute all the require steps to retrieve information from the core dumps, FDR, crash files and related log files
to generate a complete information about the crash.

The core and FDR files will be removed right after.

This script will work on Linux only. It is expected that the gdb program is also available (to extract the core dumps backtrace).

To generate HTML documentation for this module issue the command:

    pydoc -w crash_monitor

"""

import os
import datetime
import codecs
import re
import sys
import shutil
import simplejson
import signal
import os.path
from subprocess import call,Popen,PIPE
from stat import *
import traceback
import iniparse

# back port of bin function to Python 2.4
def dec2bin(s):
	if s <= 1:
		return str(s)
	else:
		return dec2bin(s >> 1) + str(s & 1)

def fix_threadid(thread_id):
	"""
	Expects a thread id as parameter and will convert it to a proper value if necessary.

	See Doc ID 1500676.1 for more information about that.
	"""
	id = int(thread_id)

	if id > (2**31):
		bin_str = dec2bin(id)
		bin_digits = []

		for digit in bin_str:

			if digit == '1':
				bin_digits.append('0')
			else:
				bin_digits.append('1')

			temp = int(''.join(bin_digits[1:]),2)
			temp += 1

		return ("-" + str(temp) )
	else:
		return thread_id

def find_thread_id(filename):
	"""
	Expects a complete path to a FDR file as parameter.
	It will search for the thread id corresponding to the point the crash occurred and will return it.
	"""
	csv_file = codecs.open(filename,'r')
	thread_id = None
	for line in csv_file:
		fields = line.split(',')

		#6859951,1430765202,2509233040,Fdr_FDR,Fdr Internal,FdrSub_FDR_CRASH,** CRASHING THREAD **,0,0,"",""
		if ( ( len(fields) >= 6 ) and ( fields[6] == '** CRASHING THREAD **' ) ):
			thread_id = fields[2]
			break

	csv_file.close()
	return thread_id

def manage_comp_alias(crashes, pid, default_log, archive_dir, crash_dir):

	try:

		if not crashes[pid].has_key('comp_alias'):
			comp_alias = find_comp_alias(pid, default_log)

			if comp_alias is None:
				print "\tCouldn't find the pid %s in the enterprise log file." % ( str(pid) )
				last_log = os.path.join(find_last(archive_dir),enterprise_log_file)
				comp_alias = find_comp_alias(pid, last_log)

				if not comp_alias is None:
					crashes[pid]['enterprise_log'] = last_log
					shutil.copy2( last_log, crash_dir )
			else:
				crashes[pid]['enterprise_log'] = default_log
				shutil.copy2( default_log, crash_dir )
                
			if comp_alias is None:
				print "\tAll attempts to locate the component alias for %s failed." % ( str(pid) )
			else:
				crashes[pid]['comp_alias'] = comp_alias

	except:
		print "Unexpected error!"
		all_info = sys.exc_info()

		if not all_info[0] is None:
			print 'exception type is %s' % (all_info[0])

		if not all_info[1] is None:
			print 'exception value is %s' % (all_info[1])

		if not all_info[2] is None:
			print 'traceback: '
			print traceback.print_exception(all_info[0], all_info[1], all_info[2])

		# to be sure that no circular references will hang around
		all_info = ()

def find_comp_alias(pid, enterprise_log):
	print '\tTrying to locate the component alias with PID %s in the Siebel Enterprise log file %s... ' % (str(pid),enterprise_log),

	if ( os.path.exists( enterprise_log ) ):
		#ServerLog       ProcessExit     1       0000257f551658c2:0      2015-04-09 18:07:27     eCommunicationsObjMgr_esn       23340    SBL-OSD-02006   Process 23340 exited with error - El proceso se 
		regex = re.compile('.*(Process\s' + str(pid) + '\sexited\swith\serror).*', re.UNICODE | re.DOTALL)
		log = codecs.open(enterprise_log,'r')

		for line in log:
			match = regex.match(line)

			if match:
				fields = line.split()
				log.close()
                
			if ( len(fields) >= 6 ):
				print 'found it.'
				return fields[6]
			else:
				print 'invalid line that matches the regex of process failure: "line".'
				return None

		log.close()
		print 'not found'
	else:
		print 'file %s does not exists, cannot search for pid.' % ( enterprise_log )
    
	return None
    
def find_logs(log_dir, regex, crash_dir, pid, thread_num):
	logs_counter = 0

	for log_filename in os.listdir(log_dir):
		match = regex.match(log_filename)

		if match:
			original = os.path.join(log_dir,log_filename)
            
			try:
				comp_log = codecs.open(original,'r')
				header = comp_log.readline()
				comp_log.close()
				# file header checking
				header_fields = header.split(' ')
                
				if ( not( len(header_fields) >= 19 ) ):
					print '%s does not have a valid header line: "%s"' % ( log_filename, header )
				else:
					if ( ( header_fields[13] == pid ) and ( header_fields[15] == thread_num ) ):
						logs_counter += 1
						shutil.copy2( original, ( os.path.join( crash_dir,log_filename ) ) )
                
			except UnicodeEncodeError, inst:
				print '\n\tAn error occurred when reading "%s": %s' % ( original, str(inst) )

			except:
				print "Unexpected error:", sys.exc_info()[0]
    
	return logs_counter

def signal_map():
	# created from kill -l output on OEL:
	#
	# $ kill -l
	# 1) SIGHUP       2) SIGINT       3) SIGQUIT      4) SIGILL
	# 5) SIGTRAP      6) SIGABRT      7) SIGBUS       8) SIGFPE
	# 9) SIGKILL     10) SIGUSR1     11) SIGSEGV     12) SIGUSR2
	# 13) SIGPIPE     14) SIGALRM     15) SIGTERM     16) SIGSTKFLT
	# 17) SIGCHLD     18) SIGCONT     19) SIGSTOP     20) SIGTSTP
	# 21) SIGTTIN     22) SIGTTOU     23) SIGURG      24) SIGXCPU
	# 25) SIGXFSZ     26) SIGVTALRM   27) SIGPROF     28) SIGWINCH
	# 29) SIGIO       30) SIGPWR      31) SIGSYS      34) SIGRTMIN
	# 35) SIGRTMIN+1  36) SIGRTMIN+2  37) SIGRTMIN+3  38) SIGRTMIN+4
	# 39) SIGRTMIN+5  40) SIGRTMIN+6  41) SIGRTMIN+7  42) SIGRTMIN+8
	# 43) SIGRTMIN+9  44) SIGRTMIN+10 45) SIGRTMIN+11 46) SIGRTMIN+12
	# 47) SIGRTMIN+13 48) SIGRTMIN+14 49) SIGRTMIN+15 50) SIGRTMAX-14
	# 51) SIGRTMAX-13 52) SIGRTMAX-12 53) SIGRTMAX-11 54) SIGRTMAX-10
	# 55) SIGRTMAX-9  56) SIGRTMAX-8  57) SIGRTMAX-7  58) SIGRTMAX-6
	# 59) SIGRTMAX-5  60) SIGRTMAX-4  61) SIGRTMAX-3  62) SIGRTMAX-2
	# 63) SIGRTMAX-1  64) SIGRTMAX
	#
	# Its an ugly hack, but couldn't find a portable code to produce the correct result.
	# Not all signals were implemented anyway.
	return dict(zip(list(range(1,32)),
		['SIGHUP','SIGINT','SIGQUIT','SIGILL','SIGTRAP','SIGABRT','SIGBUS','SIGFPE','SIGKILL','SIGUSR1','SIGSEGV','SIGUSR2','SIGPIPE','SIGALRM','SIGTERM','SIGSTKFLT','SIGCHLD','SIGCONT','SIGSTOP','SIGTSTP','SIGTTIN','SIGTTOU','SIGURG','SIGXPU','SIGXFSZ','SIGVTALRM','SIGPROF','SIGWINCH','SIGIO','SIGPWR','SIGSYS']))

def signal_handler(signal, frame):
	print 'Received SIGINT signal'
	print 'Resuming operations, please wait'

# returns the last created directory
def find_last(log_archive_dir):
	print 'Locating newest archive directory under "%s"...' % ( log_archive_dir )
	archives = {}

	for archive_dir in os.listdir( log_archive_dir ):
		full_path = os.path.join(log_archive_dir, archive_dir)
		statinfo = os.stat(full_path)

	if ( S_ISDIR( statinfo.st_mode ) ):
		archives[statinfo.st_mtime] = full_path
    
	entries = archives.keys()
	entries.sort(reverse=True)
	return archives[entries[0]]

def readConfig():
	"""Configuration file details

	This script uses a INI file to providing guidance of where to search for crash files and execute the expected
	steps once one if find.

	The configuration file is expected to the located at the users home directory with the filename equal to ".crash.ini".

	Details on INI format can be checked by reading the iniparse module documentation.

	The expected keys and values are described below. You don't need to use namespaces.

	- crash_archive: expects a full path of a directory that will be used to store the crash(es) information. Inside this directory, subdirectories will
	be created with the name corresponding to the string returned by today() method from datetime.date Python standard module and respective files will be located there.
	- siebel_bin: the complete path to the Siebel Server bin directory. Also, where the crash files will be located.
	- ent_log_dir: the complete path to the Siebel Enterprise log directory
	- ent_log_file: the complete path to the current Siebel Enterprise log file
	- log_archive: the complete path to the directory where the log files were rotated
	"""
	ini = iniparse.BasicConfig()
	location = os.path.join( os.environ['HOME'], '.crash.ini' )
	iniFile = open(location, mode='r')
	ini.readfp(iniFile)
	iniFile.close()
	return ini

if __name__ == '__main__':

	# to try to finish the process in case of server bounce
	signal.signal(signal.SIGINT, signal_handler)
	ini = readConfig()
	bin_dir = ini.siebel_bin
	crash_dir = os.path.join( ini.crash_archive, str(datetime.date.today()))
	enterprise_log_dir = ini.ent_log_dir
	log_archive = ini.log_archive
	enterprise_log_file = ini.ent_log_file
	enterprise_log = ini.ent_log_dir
	crashes = {}

	from_to = signal_map()

	for filename in os.listdir(bin_dir):

	    if filename[0:5] == 'core.':
		print 'Found core dump %s' % (filename)
		
		if (not(os.path.isdir(crash_dir))):
		    os.mkdir(crash_dir)

		core_path = os.path.join(bin_dir, filename)
		statinfo = os.stat(core_path)
		last_mod = datetime.datetime.fromtimestamp(statinfo.st_mtime)
		output = (Popen(['file', core_path], stdout=PIPE).communicate()[0]).rstrip()
		#/<PATH>/siebsrvr/bin/core.23340: ELF 32-bit LSB core file Intel 80386, version 1 (SYSV), SVR4-style, from 'siebmtshmw'
		bin = ((output.split(','))[-1]).replace(" from '","").replace("'","")
		# this can raise an exception
		pid = int(( filename.split('.') )[1])
		
		if ( crashes.has_key(pid) ):
		    crashes[pid]['core'] = { 'filename': filename, 'size' : statinfo.st_size, 'last_mod' : str(last_mod), 'executable' : bin, 'generated_by' : 'unknown' } 
		else:
		    crashes[pid] = { 'core' : { 'filename': filename, 'size' : statinfo.st_size, 'last_mod' : str(last_mod), 'executable' : bin, 'generated_by' : 'unknown' } } 

		print '\tExtracting information from the core file with gdb... ',
		gdb_cmd_filename = os.path.join(crash_dir, 'gdb.cmd')
		gdb = open(gdb_cmd_filename,'w')
		gdb.write('bt\n')
		gdb.close()
		gdb_out = open( (os.path.join(crash_dir,'gdb_core.txt')),'a')
		gdb_out.write('Analyzing core ' + core_path + '\n')
		popen = Popen(['/usr/bin/gdb',bin,os.path.join(bin_dir,bin,core_path),'-batch','-x',gdb_cmd_filename],bufsize=0,shell=False,stdout=PIPE)
		out,err = popen.communicate()
		signal_regex = re.compile(r'^Program\sterminated\swith\ssignal\s(\d+)',re.MULTILINE)
		found = signal_regex.findall(out)
		    
		if len(found) >= 1:
		    crashes[pid]['core']['generated_by'] = from_to[ int(found[0]) ]
		    
		gdb_out.write(out)
		gdb_out.close()
		    
		if err is not None:
		    print 'GDB returned an error: %s.' % ( err )
		else:
		    print 'done.'

		os.remove(core_path)
		os.remove(gdb_cmd_filename)
		manage_comp_alias(crashes=crashes, pid=pid, default_log=enterprise_log, archive_dir=log_archive, crash_dir=crash_dir)
		continue

	    if filename[-4:] == '.fdr':
		print 'Found FDR file %s' % ( filename )

		if (not(os.path.isdir(crash_dir))):
		    os.mkdir(crash_dir)

		fdr_path = os.path.join(bin_dir, filename)
		statinfo = os.stat(fdr_path)
		last_mod = datetime.datetime.fromtimestamp(statinfo.st_mtime)

		# this can raise an exception
		#T201504072041_P028126.fdr
		pid = int((((filename.split('_'))[1].split('.'))[0])[1:])

		if ( crashes.has_key(pid) ):
		    crashes[pid]['fdr'] = { 'filename' : filename, 'size' : statinfo.st_size, 'last_mod' : str(last_mod) }
		else:
		    crashes[pid] = { 'fdr' : { 'filename' : filename, 'size' : statinfo.st_size, 'last_mod' : str(last_mod) } }

		csv_file = os.path.join(crash_dir,(filename + '.csv'))
		
		ret = call(['sarmanalyzer','-o', csv_file, '-x', '-f', fdr_path])
		if ret != 0:
		    print ' '.join(('\tsarmanalizer execution failed with code',str(ret)))

		os.remove(fdr_path)
		    
		thread_id = find_thread_id(csv_file)
		if thread_id is not None:
		    crashes[pid]['thread'] = fix_threadid(thread_id)
		else:
		    print " ".join(("\tCouldn't find the thread id of the crashing thread of process", str(pid),'by reading the export FDR information'))

		manage_comp_alias(crashes=crashes, pid=pid, default_log=enterprise_log, archive_dir=log_archive, crash_dir=crash_dir)
		continue

	    if filename == 'crash.txt':
		print 'Found file crash.txt, copying it... ',
		if (not(os.path.isdir(crash_dir))):
		    os.mkdir(crash_dir)
		os.rename( (os.path.join( bin_dir,filename ) ) , ( os.path.join( crash_dir,filename ) ) )
		print 'done.'

	if len(crashes):
	    for pid in crashes.keys():
		
		if crashes[pid].has_key('comp_alias'):
		    log_counter = 0

		    if crashes[pid].has_key('thread'):
			print 'Searching for log files of component %s, pid %s, thread id %s...' % ( crashes[pid]['comp_alias'], str(pid), crashes[pid]['thread'] ),
			ent_regex = re.compile(crashes[pid]['comp_alias'] + '.*\.log')
			#log_dir, regex, crash_dir, pid, thread_num
			log_counter = find_logs(log_dir=enterprise_log_dir, regex=ent_regex, crash_dir=crash_dir, pid=str(pid), thread_num=crashes[pid]['thread'])

			if ( log_counter > 0 ):
			    print 'found %s log files.' % ( str(log_counter) )
			else:
			    print 'no log files found in %s.' % ( enterprise_log_dir )
			    print 'Trying to find in the logarchive... ',
			    # sane setting
			    log_counter = 0
			    last_one = find_last( log_archive )
			    log_counter = find_logs(log_dir=last_one, regex=ent_regex, crash_dir=crash_dir, pid=str(pid), thread_num=crashes[pid]['thread'])
			    
			    if ( log_counter > 0 ):
				print 'found %s log files.' % ( str(log_counter) )
			    else:
				print 'no log files found in %s' % ( last_one )
		    else:
			print 'PID %s is missing thread id, cannot search for logs.' % ( str(pid) )

		else:
		    print 'PID %s is missing component alias, cannot search for logs.' % ( str(pid) )

	    print '\n----\nDumping technical details of component crashes found:\n %s\n----' % (str(crashes))
	    print 'Also dumping all technical details found in JSON format to crashes_info.json file'
	    crashes_info = os.path.join(crash_dir, 'crashes_info.json')
	    fp = codecs.open(crashes_info,'w',encoding='utf8')
	    simplejson.dump(crashes,fp)
	    fp.close()
	    print '\n'

	print 'End of report. If files were found, they will be located in the home directory of the server, under %s directory.' % (crash_dir)

