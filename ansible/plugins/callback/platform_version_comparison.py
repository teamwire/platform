#!/usr/bin/env python3

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible.plugins.callback import CallbackBase
import subprocess,sys,os,pwd

DOCUMENTATION = '''
callback: platform_version_comparison
description:
    - This plugin compare curent vs applied platform version
short_description: Compares the platform version
'''

class CallbackModule(CallbackBase):
    """ This plugin compares the current and applied platform versions."""

    CALLBACK_VERSION = 2.0
    CALLBACK_NAME    = 'platform_version_comparison'
    CALLBACK_TYPE    = 'aggregate'

    def __init__(self):
        '''Initialising message variable. This will later be extended with
        the platform version and will also show the banner at the beginning.'''

        super(CallbackModule,self).__init__()
        self._display.banner("TEAMWIRE PLATFORM [Pre flight check plugin]")
        self.msg = ""
        self.cwd = os.getcwd()
        self.whiteList = list()
        self.whiteList_path = '/home/teamwire/platform/ansible/plugins/callback_white.list'
        self._applied_plaform_version   = "NONE"
        self._checkout_platform_version = "NONE"
        self.run_allowed = False
        self.playbook_user = pwd.getpwuid( os.getuid() )[ 0 ]

    def get_whitelist_playbooks(self):
        try:
            self.whiteList = [line.strip('\n') for line in open(self.whiteList_path)]
        except IOError as e:
            print("callback playbook whitelist not found: ",e)
            sys.exit(1)

    def get_applied_platorm_version(self):
        '''Open the file where the applied platform version is set.
        Read the content into the variable "applied_platform_version"'''

        try:
            applied_platform_version_file = open('/etc/platform_version','r')
            applied_platform_version = applied_platform_version_file.read()
        except IOError:
            self._display.warning("Could not determine applied platform version")
            applied_platform_version = "Unknown applied version"

        self._applied_plaform_version = applied_platform_version.strip()
        self.msg+= "applied platform version:\t" + applied_platform_version

    def get_checkout_platform_version(self):
        '''Open the git config file where the checkout platform version is set.
        Read the content into the variable "checkout_platform_version"'''

        try:
            git_path = "--git-dir=%s/../.git" % self.cwd

            if not os.path.isdir("%s/../.git"%self.cwd):
                self._display.error("Playbooks must be executed from platform/ansible directory(%s)" % git_path)
                sys.exit(1)

            checkout_platform_version_cmd = subprocess.Popen(["git",git_path,"describe","--always"],stdout=subprocess.PIPE)
            checkout_platform_version = checkout_platform_version_cmd.communicate()[0].decode('utf-8').strip()

        except IOError:
            self._display.warning("Could not determine checkout platform version")
            checkout_platform_version = "Unknown checkout version"

        self._checkout_platform_version = checkout_platform_version
        self.msg+= "checkout platform version:\t" + checkout_platform_version

    def check_current_user(self):
        '''Check if current user is user `teamwire`. Only user `teamwire` is allowed
        to run playbooks.'''
        self._display.v("Current user: " + self.playbook_user)
        if not self.playbook_user in "teamwire":
            self._display.error("Playbooks must run as user Teamwire!")
            sys.exit(1)

    def v2_playbook_on_start(self, playbook):
        '''Returns the applied/checkout platform version on every playbook run'''

        if not "TW_DEV_MODE" in os.environ :
            self.check_current_user()
            self.playbook = playbook
            self.msg += "\nEntrypoint:\t\t\t" + self.playbook._file_name + "\n"
            self.get_applied_platorm_version()
            self.get_checkout_platform_version()
            self._display.v(self.msg)
            self.get_whitelist_playbooks()

            for playbook_allowed in self.whiteList:
                if not (playbook_allowed in self.playbook._file_name):
                    if self._applied_plaform_version == self._checkout_platform_version:
                        self.run_allowed = True
                else:
                    self.run_allowed = True
        else:
            self._display.display("Running ansible in DEV-MODE without version check!!!")
            self.run_allowed = True

        if not self.run_allowed:
            self._display.error("The applied Platform version( %s) doesn't match the checkout version( %s): you cannot run playbook: %s" %
                            (self._applied_plaform_version, self._checkout_platform_version, self.playbook._file_name))
            sys.exit(1)
