#!/usr/bin/python

import sys, re, pexpect, exceptions
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

def get_vm_status(conn, options):
    cmd = "%s --nologo showvminfo %s" % (vboxmanage, options["-n"])
    conn.send_eol(cmd)
    re_state = re.compile('State:\s+(\w+)\s', re.MULTILINE|re.DOTALL)
    conn.log_expect(options, re_state, int(options["-Y"]))
    status = conn.match.group(1).lower()
    if status.startswith("running"):
        return "on"
    else:
        return "off"

def set_vm_status(conn, options):
    if options["-o"] == "on":
        cmd = "%s --nologo startvm %s" % (vboxmanage, options["-n"])
   else:
        cmd = "%s --nologo controlvm %s poweroff" % (vboxmanage, options["-n"])
    conn.send_eol(cmd)
    conn.log_expect(options, options["-c"], int(options["-g"]))
    return

def main():
    device_opt = [ "help", "version", "agent", "quiet", "verbose", "debug",
        "action", "ipaddr", "login", "passwd", "passwd_script", "secure",
        "port", "identity_file", "inet4_only", "inet6_only", "cmd_prompt",
        "power_timeout", "shell_timeout", "login_timeout", "power_wait" ]

    atexit.register(atexit_handler)
    all_opt["cmd_prompt"]["default"] = [r"\$"]
    all_opt["secure"]["default"] = 1
    options = check_input(device_opt, process_input(device_opt))

    docs = {}
    docs["shortdesc"] = "Fence agent for VirtualBox over SSH"
    docs["longdesc"] = "fence_vbox is a fence agent that connects to a VirtualBox host. It uses VBoxManage to manipulate the VMs that are part of the cluster."
    docs["vendorurl"] = "http://www.virtualbox.org"
    show_docs(options, docs)

    options["eol"] = "\r"

    conn = fence_login(options)
    result = fence_action(conn, options, set_vm_status, get_vm_status)
    conn.send_eol("exit")
    conn.close()
    sys.exit(result)

if __name__ == "__main__":
    main()Appendix B
