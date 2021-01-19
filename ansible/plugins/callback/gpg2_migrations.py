#!/usr/bin/python2.7

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible.plugins.callback import CallbackBase
import subprocess,sys,os,pwd,json

DOCUMENTATION = '''
callback: GPG2_migrations
description:
    - Show a warning for all installations which are currently not migrate to GPG2
short_description: Check GPG version is 2.x
'''

warningMSG = """
================================ W A R N I N G ================================

You are about to install a new platform version. From this version on GPG2 is
required. Therefore it is necessary to execute the migration script for GPG2 and
restart the teamwire environment. If you have any questions, please contact the
support.

================================ W A R N I N G ================================

Do you really want to continue with the update now(YES/[NO])?
"""

class CallbackModule(CallbackBase):
    """ This plugin test for the new GPG version."""

    CALLBACK_VERSION = 2.0
    CALLBACK_NAME    = 'gpg2_migrations'
    CALLBACK_TYPE    = 'aggregate'

    def __init__(self):
        super(CallbackModule,self).__init__()
        self._display.banner("TEAMWIRE PLATFORM [Check gpg2 migration state]")
        self._stateFilePath = "/etc/gpg2Migration"
        self._ENABLED       = "1"

    def hasMigration(self):
        stateFilePath  = self._stateFilePath
        isEnabled      = False

        if os.path.isfile(stateFilePath):
            stateFile = open(stateFilePath)
            currState = stateFile.read(1)
            stateFile.close()

            if currState == self._ENABLED:
                isEnabled = True

        output = os.popen('/bin/bash /etc/ansible/facts.d/vault.fact')
        vault  = json.load(output)

        '''Check if this is the first installation. Then no migration is needed'''
        if vault['initialized'] == "":
            isEnabled = True
            os.environ["GPG_ISENABLED"] = self._ENABLED

        return isEnabled

    def v2_playbook_on_start(self, playbook):
        '''Check if platform is already migrated to GPG2 '''
        if not "TW_DEV_MODE" in os.environ:
            if not self.hasMigration():
                self._display.display(warningMSG)
                runUpdate = raw_input("> ")

                if not runUpdate.lower() in "yes" or len(runUpdate) == 0:
                    self._display.display("Installation/Updated canceled by user.Bye..")
                    sys.exit(0)