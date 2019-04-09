#!/bin/bash

# -----------------------------------------------------------------------------
# SCRIPT VARS
#
# The following vars could be
# set directly in this script
# or via commandline options.
# -----------------------------------------------------------------------------
DB='teamwire'				# Name of the database
HOST='127.0.0.1'			# IP/Domain of database
USER=''					# Loginuser
PASS=${PASS:-''}			# Password of user. DO NOT SET THIS IN THE SCRIPT!
TASK='helpme'				# Default task of this script
OUTDIR='/tmp/'  			# Path of backup dir
NFS_PATH=""				# Optional path of NFS mount
MAX_BACKUPS=20				# Max. number of backups to keep
MAX_LOCK=3600				# Max. lock time
IN_FILE=''				# Dump to recover
VAULT_SECRET_PATH="database/password" 	# Path in secretstore
VAULT_ADDR="127.0.0.1"                  # Vault IP

# -----------------------------------------------------------------------------
# The following script variables should not set
# by hand.
# -----------------------------------------------------------------------------
declare -r FALSE=1
declare -r TRUE=0
declare -r DATE=$(date +"%Y-%m-%d_%s")
declare -r SCRIPT_NAME=$(basename "$0")
declare -r LOCKFILE="/tmp/$SCRIPT_NAME.lock"
declare -r MAX_THREADS=$(grep -c ^processor /proc/cpuinfo)

TMP_ARCHIVE=""
isVaultUsed=$FALSE
isPassEnabled=$FALSE
FORCE=$FALSE		# Force to override a database table if true ( on recovery )
VAULT=$FALSE

# -----------------------------------------------------------------------------
# Catch "[cntrl] + c" user input. See func ctrl_c
# -----------------------------------------------------------------------------
trap ctrl_c INT

# -----------------------------------------------------------------------------
# Test that mydumper is installed. Otherwise exit
# -----------------------------------------------------------------------------
if [ ! -x /usr/bin/mydumper ];then
	exit 1
fi

# -----------------------------------------------------------------------------
# Run this script only if no lockfile exist or lockfile is older than in MAX_LOCK
# specified seconds. This will prevent, that this script is executed multiplied
# time e.g. by cron.
# -----------------------------------------------------------------------------

if [ -e "$LOCKFILE"  ] && [ $(expr $(date +'%s') - $(cat "$LOCKFILE")) -le $MAX_LOCK ];then echo "LOGFILE ERROR!";exit 1;fi

# Create timestamp in lockfile
date +"%s" > "$LOCKFILE"

# -----------------------------------------------------------------------------
# FUNCTION:     helpme
# ARGUMENTS:    none
# RETURN:       void/null
# EXPLAIN:      If no commandline args
#		passed to the script, this
#		message will be shown
# -----------------------------------------------------------------------------
helpme() {

	echo "usage: $SCRIPT_NAME -t|--task <operation> [-d |--database <dbname>][-h|--host <hostname>][-u|--user <username>]
	[-p|--pass][-o|--outputdir <path>][-n|--nfs-path <path>][-m|--max-backups <number>]
        [-i|--in-file <path>][-f|--force][-s|--secret-path <path>][--help][--non-interactive][--vault]

	where:

	MODE
	---------
	-t|--task         = Task to perform (backup||restore)

	GENERAL
	---------
	-d|--database     = Databasename
	-h|--host         = Hostname
	-u|--user         = Loginuser
	-p|--pass         = Interactive password input
	-s|--secret-path  = Vault secret path. Only used in combination with
			    option '--vault'
	--help            = shows this text
        --non-interactive = Password will not be ask. You have to set it with
			    option '-p' or '--vault -s...'
        --vault           = Enables the usage of vault. Secret path is set with
			    option '-s'
	--vault-addr	  = Vault address is set to IP 127.0.0.1. Set new
			    Vault address if needed.
        BACKUP
	--------
	-o|--outdir       = Path where to dump
	-n|--nfs-path     = Path to nfs mount. Save dumps in addition to this path
	-m|--max-backups  = Max backups to keep -> default 20

        RESTORE
	--------
	-i|--in-file      = Path to file you like to recover
	-f|--force        = Force override (DROP) DB tables while recovering

	EXAMPLE: (Set always -p option)
	-------------------------------

	Backup:
	$SCRIPT_NAME -t backup -p

	Backup with path:
	$SCRIPT_NAME -t backup -o /path/to/dest -p

	Restore:
	$SCRIPT_NAME -t restore -p -i /path/to/dump

	Restore (drop existing tables)
	$SCRIPT_NAME -t restore -p -i /path/to/dump -f -d test_db

        Secret path is set without a leading slash:
	--secret-path my/path

	Use secret from vault:
	$SCRIPT_NAME --vault -s path/to/secret

	Use secret from vault and set ip:
	$SCRIPT_NAME --vault --vault-addr 10.0.0.10 -s path/to/secret
	"
}

# ------------------------------------------------------------------------------
# FUNCTION:	backup_db
# ARGUMENTS:	none
# RETURN:	void/null
# EXPLAIN:	Creates a backup from user
#		specified database. Otherwise
#		it makes an backup with default
#		values from $DB. mydumper runs in
#		parallelism and should be faster
#		than default tools.
# -----------------------------------------------------------------------------
backup_db() {

	# Check if password is set. If pass is not set exit script
	if [ -z "$PASS" ] && [ ! -e "$HOME/.my.cnf" ];then
		echo "Pass not set!"
		exit_on_failure
	fi

	# Test that backup directory exists. Otherwise create it.
	local SRC="$OUTDIR/tmp"
	[ ! -e $SRC ] && mkdir -p $SRC

	echo "Start dumping DB $DB..."

	# Run mydumper with maximum available threads and with user
	# defined option.
	if [ ! -z "$PASS" ];then

		create_temp_conf

		mydumper \
		--database=$DB \
		--host=$HOST \
		--outputdir="$OUTDIR/tmp" \
		--threads="$MAX_THREADS"

	elif [ -z "$PASS" ] && [ -e "$HOME/.my.cnf" ];then

		mydumper \
                --database=$DB \
                --host=$HOST \
                --outputdir="$OUTDIR/tmp" \
                --threads="$MAX_THREADS"

	fi

	check_prev_exitcode $? "Error while backup"
	# Define some local vars to archive the SQL-dump. mydumper seperates
	# all dumps in one file per table. After archiving the files we got
	# all dumps in the same place sorted by date.If NFS_PATH is defined
	# we will also keep a backup on NFS mount and delete tmp dir.
	echo "Run archiving..."

	local EXTENS="_dump.tar.gz"
	local TAR_ARCHIVE="$OUTDIR/${DATE}_${DB}_${HOST}_$EXTENS"
	TMP_ARCHIVE=$TAR_ARCHIVE

	tar Pcfz "$TAR_ARCHIVE" $SRC &&

	check_prev_exitcode $? "Error while archiving"

	if [ ! -z $NFS_PATH ]; then
		cp "$TAR_ARCHIVE" $NFS_PATH;
		check_prev_exitcode $? "Error while backup to NFS share"
	fi &&

	rm -rf "$OUTDIR/tmp"

	# If the previous process exit on failure we want also quit this script
	# with a failure.
	check_prev_exitcode $? "Error while remove tmp dir"

	# Count current backups. Rest should be self explained :-)
	CURR_BACKUPS=$(ls $OUTDIR | wc -l)
	while (( CURR_BACKUPS > MAX_BACKUPS ));do

		echo "Maximum number of backups reached($CURR_BACKUPS/$MAX_BACKUPS)."
		OLDEST_BACKUP=$(find /var/local/backups/db/production/ -type f -printf '%T+ %p\n' | sort | head -n 1 | awk '{print $2}')

		echo "Delete oldest Backup: $OLDEST_BACKUP"
		rm "$OLDEST_BACKUP"

		CURR_BACKUPS=$(ls $OUTDIR | wc -l)

	done
	echo "Current number of backups $CURR_BACKUPS/$MAX_BACKUPS"

	# CREATE LATEST
	rm -f "$OUTDIR/LATEST.dump"
	ln -s "$TAR_ARCHIVE" "$OUTDIR/LATEST.dump"

	rm -f "$HOME/.my.cnf"

}

# -----------------------------------------------------------------------------
# FUNCTION:     recover_db
# ARGUMENTS:    none
# RETURN:       void/nothing
# EXPLAIN:      Recovers a dump from a specified path. It also drops any
#		existing table before importing it.
# -----------------------------------------------------------------------------
restore_db() {

	# Check if password is set. If pass is not set exit script
	[ -z "$PASS" ] && echo "Pass not set!" && exit_on_failure

	if [ -z $IN_FILE ];then
		echo "You have to specify a path to the dumpfile to recover"
		exit_on_failure
	fi

	# Create temp structure
	DUMPFILE=$IN_FILE
	DIR_DUMP=$(dirname $DUMPFILE)
	DIR_TMP="/tmp/recv"
	DIR_CURR=$(pwd)

	mkdir -p $DIR_TMP; cd $DIR_TMP || exit_on_failure
	check_prev_exitcode $? "Could not create tmp dir!"

	tar xfvz $DUMPFILE --transform='s/.*\///'
	check_prev_exitcode $? "Error while extracting archive"

	echo "DEBUG FORCE: $FORCE"
	if [ $FORCE -eq $TRUE ]; then
		myloader \
		--database=$DB \
		--host=$HOST \
		--user=$USER \
		--password="$PASS" \
		--directory="$DIR_TMP" \
		--threads="$MAX_THREADS" \
		--overwrite-tables \
		--verbose=3
	else
		myloader \
		--database=$DB \
		--host=$HOST \
		--user=$USER \
		--password="$PASS" \
		--directory="$DIR_TMP" \
		--threads="$MAX_THREADS" \
		--verbose=3
	fi
	check_prev_exitcode $? "Error while recovering (dumps) into database"

	# Housekeeping
	cd "$DIR_CURR" || exit_on_failure

	rm -rf $DIR_TMP
	rm -f "$HOME/.my.cnf"

	check_prev_exitcode $? "Error on Housekeeping jobs after recovery"

	echo "Recovering process finish."
}
# -----------------------------------------------------------------------------
# FUNCTION:     create_temp_conf
# ARGUMENTS:    none
# RETURN:       void/nothing
# EXPLAIN:      Creates a temporary config file, which
#               could be read by mydumper to make the passwords
#		not visible in the processlist
# -----------------------------------------------------------------------------
create_temp_conf() {

	TMPFILE="$HOME/.my.cnf"
	touch "$TMPFILE"
	chmod 0600 "$TMPFILE"

	echo "TEMPFILE   $TMPFILE"
	echo -e "[mydumper]\nuser=$USER\npassword=$PASS" > "$TMPFILE"

}

# -----------------------------------------------------------------------------
# FUNCTION:	ask_pass
# ARGUMENTS:	none
# RETURN:	void/nothing
# EXPLAIN:	This function processes the passwords.
# 		Here you specify whether the password
#		is to be queried by Vault, via the
#		command line or interactively.
# -----------------------------------------------------------------------------
ask_pass() {

	# If no vault is set to be used and no password is set, then prompt
	# for a password. This is an interactive-mode
	if [ "$isVaultUsed" == "$FALSE" ] && [ "$isPassEnabled" == "$FALSE" ];then
		read -r -s -p "Please enter DB pass: " PASS;echo;
	fi
	# If both is set password and vault, then exit with a failure. Only
	# one method is possible.
	if [ "$isVaultUsed" == "$TRUE" ] && [ "$isPassEnabled" == "$TRUE" ];then
		echo "ERROR: You can use Vault option together with password option."
		exit_on_failure
	fi
	# If Vault is set then curl the password from vault secret store.
	if [ "$isVaultUsed" == "$TRUE" ];then
		vault_read_pass
		check_prev_exitcode $? "Error while reading Vault pass"
	fi
	# If isPassEnabled = TRUE then pass is already set! So no further
	# checks needed.

}

# -----------------------------------------------------------------------------
# FUNCTION:     check_prev_exitcode
# ARGUMENTS:    $1 = exitCode |  $2 = Message
# RETURN:       void/nothing
# EXPLAIN:      This func is call to check prev.
#               <exitCode>. If the Exitcode is not equal
#               0, then throw <message> and exit this script
#               with error 1. Bevore do the housekeepingstuff
#               defined in <exit_on_failure>
# -----------------------------------------------------------------------------
check_prev_exitcode() {
	local exitCode=$1
	local message=$2
	[ "$exitCode" -ne 0 ] &&  echo "$message" && exit_on_failure
}

# -----------------------------------------------------------------------------
# FUNCTION:     ctrl_c
# ARGUMENTS:    none
# RETURN:       void/null
# EXPLAIN:      If the user press [ctrl] + c, this
#		function will execute some house-
#		keeping jobs e.g.
#		remove lockfile, tmp files, etc.
#		by calling the exit_on_failure func
#		and exit with code 1
# -----------------------------------------------------------------------------
ctrl_c() { echo "[ctrl] + c :pressed!Exit";exit_on_failure; }

# -----------------------------------------------------------------------------
# FUNCTION:     exit_on_failure
# ARGUMENTS:    none
# RETURN:       void/null
# EXPLAIN:      This func reads the Password of the DB
#               via API.
# -----------------------------------------------------------------------------
exit_on_failure() {

	# Remove lockfile, so that the script
	# can be executed
	rm "$LOCKFILE"

	# Remove temporary created files
	rm -rf "$OUTDIR/tmp"

	# A maximum number of backups are specified
        # by MAX_BACKUPS. If the script would keep
        # broken backup files, the number of backups
        # would grow without having consistent backups.
	rm -f "$TMP_ARCHIVE"

	# Remove temp recover dir
	rm -rf /tmp/recv/

	# Remove temp mysql config file
	rm -f "$HOME/.my.cnf"

	# Exit script with failure, so that e.g. a cron-
	# job could send an email.
	exit 1
}

# -----------------------------------------------------------------------------
# FUNCTION:     vault_read_pas
# ARGUMENTS:    Token ( String )
# RETURN:       String
# EXPLAIN:      Execute needed housekeeping fun
#
# -----------------------------------------------------------------------------
vault_read_pass() {
	if [ -z  "$VAULT_TOKEN" ];then
		echo "No Vault token set! Exit now"
		exit_on_failure
	fi
	PASS=$(curl -k -s \
	     -H "X-Vault-Token: $VAULT_TOKEN" \
	     -X GET \
	     https://$VAULT_ADDR:8200/v1/$VAULT_SECRET_PATH | \
	     jq -r '.data.value')
}

while [ $# -gt 0 ]; do
	case "$1" in
		-d|--database)
			DB="$2"
			;;
		-h|--host)
			HOST="$2"
			;;
		-u|--user)
			USER="$2"
			;;
		-p|--pass)
			isPassEnabled=$TRUE
			PASS="$2"
			;;
		-t|--task)
			TASK="$2"
			;;
		-o|--outdir)
			OUTDIR="$2"
			;;
		-n|--nfs-path)
			NFS_PATH="$2"
			;;
		-m|--max-backups)
			MAX_BACKUPS="$2"
			;;
		-i|--in-file)
			IN_FILE="$2"
			;;
		-f|--force)
			FORCE=$TRUE
			;;
                -s|--secret-path)
			VAULT_SECRET_PATH="$2"
			;;
		--help)
			TASK="helpme";
			;;
		--vault)
			isVaultUsed=$TRUE
			;;
		--vault-addr)
			VAULT_ADDR="$2"
			;;

	esac
	shift
done

# Executes password func
if [ $TASK != "helpme" ]; then
	ask_pass
fi
# Catch task (user input) case insensitive
if [ "${TASK,,}" = "restore" ]
then
	restore_db;
elif [ "${TASK,,}" = "backup" ]
then
	backup_db;
elif [ "${TASK,,}" = "helpme" ]
then
	helpme
else
	echo "Unknown task \"$TASK\". Use --help for further informations"
	exit_on_failure
fi

# When everything runs well, then delete lockfile before script exit
rm "$LOCKFILE"

