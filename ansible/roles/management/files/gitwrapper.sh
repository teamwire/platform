git () {
    shopt -s nocasematch
    # GIT ITSELF DOESENT KNOW ANYTHING ABOUT RELEASE TAGS. SO WE HAVE TO USE GITHUB HIGHER FEATURE TO ARCHIVE THAT
    GTRELEASE=$(curl -s -XGET https://api.github.com/repos/teamwire/platform/releases | jq '.[0].tag_name' -r)
    # CHECK IF 'platform_Version' IS DEFINED
    if [ $(grep -c -i "^platform_version" /home/teamwire/platform/ansible/group_vars/all) -ge 1 ]; then
        # GET PLATFORM VERSIN
        PV=$(grep "^platform_version" /home/teamwire/platform/ansible/group_vars/all | sed 's/\"//g' | awk '{print $2}')
        # CHECK IF PLATFORM VERSION IS EMPTY
        if [ -z $PV ]; then
            echo "ERROR. platform_version variable is not set!"
            exit 1
        # CHECK IF PLATFORM VERSION HAS LATEST TAG
        elif [ "${PV}" == "latest" ]; then
            export GTAG="master"
        # CHECK IF PLATFORM VERSION HAS RELEASE TAG
        elif [ "${PV}" == "release" ]; then
            export GTAG="${GTRELEASE}"
        else
            export GTAG="${PV}"
        fi
        /usr/bin/git checkout $GTAG 2>&1 >/dev/null
    # IF PLATFORM VERSION IS NOT DEFINED, CHECKOUT MASTER
    else
        /usr/bin/git checkout master 2>&1 >/dev/null
    fi
    # EXECUTE GIT COMMAND
    /usr/bin/git $@
}
