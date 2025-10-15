import os
import sys




def get_process_data():
    # ps = subprocess.Popen(['ps', 'aux'], stdout=subprocess.PIPE).communicate()[0]
    processes = ps.split('\n')
    # this specifies the number of splits, so the splitted lines
    # will have (nfields+1) elements
    nfields = len(processes[0].split()) - 1
    retval = []
    for row in processes[1:]:
        retval.append(row.split(None, nfields))
    return retval

wantpid = int(contents[0])
pstats = getProcessData()
for ps in pstats:
    if (not len(ps) >= 1): continue
    if (int(ps[1]) == wantpid):
        print
        "process data:"
        print
        "USER              PID       %CPU        %MEM       VSZ        RSS        TTY       STAT      START TIME      COMMAND"
        print
        "%-10.10s %10.10s %10.10s %10.10s %10.10s %10.10s %10.10s %10.10s %10.10s  %s" % (
            ps[0], ps[1], ps[2], ps[3], ps[4], ps[5], ps[6], ps[7], ps[8], ps[9])