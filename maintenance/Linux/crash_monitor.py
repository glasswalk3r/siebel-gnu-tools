#!/usr/bin/env python

import os
import datetime
import codecs
import re
import sys
import shutil
import simplejson
from subprocess import call,Popen,PIPE

# back port of bin function to Python 2.4
def dec2bin(s):
    if s <= 1:
        return str(s)
    else:
        return dec2bin(s >> 1) + str(s & 1)

# see Doc ID 1500676.1
def fix_threadid(thread_id):

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
    csv_file = codecs.open(filename,'r',encoding='utf8')
    thread_id = None
    for line in csv_file:
        fields = line.split(',')
        #6859951,1430765202,2509233040,Fdr_FDR,Fdr Internal,FdrSub_FDR_CRASH,** CRASHING THREAD **,0,0,"",""
        if ( ( len(fields) >= 4 ) and ( fields[6] == '** CRASHING THREAD **' ) ):
            thread_id = fields[2]
    csv_file.close()
    return thread_id

root = os.sep
hostname = os.environ['HOSTNAME']
enterprise = 'to implement'
home = os.environ['HOME']
bin_dir = os.path.join( home, '81', 'siebsrvr', 'bin' )
today=datetime.date.today()
crash_dir = os.path.join( home, 'crash_dir_' + str(today) )
list_filename = os.path.join(crash_dir, 'file_list.txt')
enterprise_log_dir = os.path.join(root, enterprise, 'to implement', enterprise, hostname, 'log')
enterprise_log = os.path.join(root, enterprise, 'to implement', enterprise, hostname, 'log', ( enterprise + '.' + hostname + '.log' ) )
crashes = {}

for filename in os.listdir(bin_dir):

    if filename[0:5] == 'core.':

        print 'found core dump ' + filename
        if (not(os.path.isdir(crash_dir))):
            os.mkdir(crash_dir)

        core_path = os.path.join(bin_dir, filename)
        statinfo = os.stat(core_path)
        last_mod = datetime.datetime.fromtimestamp(statinfo.st_mtime)
        output = (Popen(['file', core_path], stdout=PIPE).communicate()[0]).rstrip()
        # /<PATH>/core.23340: ELF 32-bit LSB core file Intel 80386, version 1 (SYSV), SVR4-style, from 'siebmtshmw'
        bin = ((output.split(','))[-1]).replace(" from '","").replace("'","")
        pid = int(( filename.split('.') )[1])

        if ( crashes.has_key(pid) ):
            crashes[pid]['core'] = { 'filename': filename, 'size' : statinfo.st_size, 'last_mod' : str(last_mod), 'executable' : bin } 
        else:
            crashes[pid] = { 'core' : { 'filename': filename, 'size' : statinfo.st_size, 'last_mod' : str(last_mod), 'executable' : bin } } 

        if ( sys.platform.startswith('linux') ):

            gdb_cmd_filename = os.path.join(crash_dir, 'gdb.cmd')
            gdb = open(gdb_cmd_filename,'w')
            gdb.write('bt\n')
            gdb.close()
            
            gdb_out = open( (os.path.join(crash_dir,'gdb_core.txt')),'a')
            gdb_out.write('Analyzing core ' + core_path + '\n')
            popen = Popen(['/usr/bin/gdb','siebmtshmw', os.path.join(bin_dir,bin,core_path),'-batch','-x',gdb_cmd_filename],bufsize=0,shell=False,stdout=PIPE)
            out,err = popen.communicate()
            gdb_out.write(out)
            gdb_out.close()
            print err
            os.remove(core_path)

        #ServerLog       ProcessExit     1       0000257f551658c2:0      2015-04-09 18:07:27     eCommunicationsObjMgr_esn       23340    SBL-OSD-02006   Process 23340 exited with error - El proceso se 
        regex = re.compile('.*(Process\s' + str(pid) + '\sexited\swith\serror).*', re.UNICODE | re.DOTALL)
        log = codecs.open(enterprise_log,'r',encoding='utf8')

        for line in log:
            match = regex.match(line)

            if match:
                fields = line.split()
                crashes[pid]['comp_alias'] = fields[6]
                break

        log.close()
        
        if not crashes[pid].has_key('comp_alias'):
            print "Couldn't find the pid " + str(pid) + " in the enterprise log file"
        
        continue

    if filename[-4:] == '.fdr':
        print 'found fdr ' + filename
        if (not(os.path.isdir(crash_dir))):
            os.mkdir(crash_dir)
        fdr_path = os.path.join(bin_dir, filename)
        statinfo = os.stat(fdr_path)
        last_mod = datetime.datetime.fromtimestamp(statinfo.st_mtime)
        #T201504072041_P028126.fdr
        pid = int((((filename.split('_'))[1].split('.'))[0])[1:])

        if ( crashes.has_key(pid) ):
            crashes[pid]['fdr'] = { 'filename' : filename, 'size' : statinfo.st_size, 'last_mod' : str(last_mod) }
        else:
            crashes[pid] = { 'fdr' : { 'filename' : filename, 'size' : statinfo.st_size, 'last_mod' : str(last_mod) } }

        csv_file = os.path.join(crash_dir,(filename + '.csv'))
        
        ret = call(['sarmanalyzer','-o', csv_file, '-x', '-f', fdr_path])
        if ret != 0:
            raise Exception('call sarmanalizer failed with code ' + str(ret))

        os.remove(fdr_path)

        thread_id = find_thread_id(csv_file)
        if (thread_id):
            crashes[pid]['thread'] = fix_threadid(thread_id)
        else:
            print "Couldn't find the thread id of the crashing thread of process " + str(pid)

        continue

    if filename == 'crash.txt':
        print 'found crash.txt'
        if (not(os.path.isdir(crash_dir))):
            os.mkdir(crash_dir)
        os.rename( (os.path.join( bin_dir,filename ) ) , ( os.path.join( crash_dir,filename ) ) )

if len(crashes):
    for pid in crashes.keys():
        
        if crashes[pid].has_key('comp_alias'):
            log_counter = 0

            if ( crashes[pid].has_key('comp_alias') ) and ( crashes[pid].has_key('thread') ):
                print 'Searching for log files of component ' + crashes[pid]['comp_alias'] + ' pid ' + str(pid) + ', thread id ' + crashes[pid]['thread']
                ent_regex = re.compile(crashes[pid]['comp_alias'] + '.*\.log')
                
                for log_filename in os.listdir(enterprise_log_dir):
                    match = ent_regex.match(log_filename)
                    if match:
                        original = os.path.join(enterprise_log_dir,log_filename)
                        comp_log = codecs.open(original,'r',encoding='utf8')
                        header = comp_log.readline()
                        comp_log.close()
                        ( pid_log, thread_log ) = (header.split(' '))[13:15]
                        
                        if ( crashes[pid].has_key('thread') ):
                            if ( ( pid_log == str(pid) ) and ( thread_log == crashes[pid]['thread'] ) ):
                                log_counter += 1
                                shutil.copy2( original, ( os.path.join( crash_dir,log_filename ) ) )

                print 'Found ' + str(log_counter) + ' log files'
            
        else:
            print "Don't know which component the PID is related to, cannot search for logs"

    print 'Crashes found:\n' + str(crashes)
    crashes_info = 'crashes_info.json'
    fp = codecs.open(crashes_info,'w',encoding='utf8')
    simplejson.dump(crashes,fp)
    fp.close()

print 'Finished looking for crashes'

