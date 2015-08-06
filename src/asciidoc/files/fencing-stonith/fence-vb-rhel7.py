#!/usr/bin/python -tt

import sys, re
import atexit
sys.path.append("/usr/share/fence")
from fencing import *

#BEGIN_VERSION_GENERATION
RELEASE_VERSION="0.0.1"
BUILD_DATE="(built Wed Jul 22 12:00:00 UTC 2015)"
REDHAT_COPYRIGHT="Copyright (C) Red Hat, Inc. 2004-2010 All rights reserved."
#END_VERSION_GENERATION

# @author Alejandro Galue <agalue@opennms.org>"

# Warning: the following assumes the VBoxManage command exist on the PATH
vboxmanage = "VBoxManage"

def get_vms(conn, options):
    cmd = "%s --nologo list vms" % (vboxmanage)
    conn.send_eol(cmd)
    re_list = re.compile('[$]')
    conn.log_expect(options, re_list, int(options["--shell-timeout"]))
    lines = conn.before.split('\n');
    lines.pop(0)
    lines.pop()
    vms = {}
    for line in lines:
        d = line.rstrip().split(' ')
        vms[d[0].replace('"','')] = (re.sub(r"[{}]", "", d[1]), None)
    return vms

def get_vm_status(conn, options):
    cmd = "%s --nologo showvminfo %s" % (vboxmanage, options["--plug"])
    conn.send_eol(cmd)
    re_state = re.compile('State:\s+(\w+)\s', re.MULTILINE|re.DOTALL)
    conn.log_expect(options, re_state, int(options["--shell-timeout"]))
    status = conn.match.group(1).lower()
    if status.startswith("running"):
        return "on"
    else:
        return "off"

def set_vm_status(conn, options):
    if options["--action"] == "on":
        cmd = "%s --nologo startvm %s" % (vboxmanage, options["--plug"])
    else:
        cmd = "%s --nologo controlvm %s poweroff" % (vboxmanage, options["--plug"])
    conn.send_eol(cmd)
    conn.log_expect(options, options["--command-prompt"], int(options["--power-timeout"]))
    return

def reboot_cycle(conn, options):
    cmd = "%s --nologo controlvm %s reboot" % (vboxmanage, options["--plug"])
    conn.send_eol(cmd)
    conn.log_expect(options, options["--command-prompt"], int(options["--power-timeout"]))
    return

def main():
    device_opt = ["ipaddr", "login", "passwd", "secure", "cmd_prompt", "port"]

    atexit.register(atexit_handler)

    all_opt["cmd_prompt"]["default"] = [r"\$"]
    all_opt["secure"]["default"] = '1'
    options = check_input(device_opt, process_input(device_opt))

    docs = {}
    docs["shortdesc"] = "Fence agent for VirtualBox over SSH"
    docs["longdesc"] = "fence_vbox is a fence agent that connects to a VirtualBox host. It uses VBoxManage to manipulate the VMs that are part of the cluster."
    docs["vendorurl"] = "http://www.virtualbox.org"
    show_docs(options, docs)

    options["eol"] = "\r"

    conn = fence_login(options)
    result = fence_action(conn, options, set_vm_status, get_vm_status, get_vms, reboot_cycle)
    fence_logout(conn, "exit")
    sys.exit(result)

if __name__ == "__main__":
    main()
