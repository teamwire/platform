#!/bin/bash -e

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
MAX_BACKUPS=""				# Max. number of backups to keep
IN_FILE=''				# Dump to recover
VAULT_SECRET_PATH="database/password" 	# Path in secretstore
VAULT_ADDR="127.0.0.1"                  # Vault IP
PID=$$					# Own PID
TMPFILE_PATH="$HOME/.my.cnf"

# -----------------------------------------------------------------------------
# The following script variables should not set
# by hand.
# -----------------------------------------------------------------------------
declare -r FALSE=1
declare -r TRUE=0
declare -r DATE=$(date +"%Y-%m-%d_%H-%M-%S")
declare -r SCRIPT_NAME=$(basename "$0")
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
# Execute exit_on_failure on any errors or on exit
# -----------------------------------------------------------------------------
trap exit_on_failure ERR
trap housekeeping EXIT

# -----------------------------------------------------------------------------
# Test that mydumper is installed. Otherwise exit
# -----------------------------------------------------------------------------
if [ ! -x /usr/bin/mydumper ];then
	exit 1
fi

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
	[-i|--in-file <path>][-f|--force][-s|--secret-path <path>][--help][--vault]

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

	CONFIG
	--------
	--config-file     = Path to self named config file

	EXAMPLE: (Set always -t option)
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
	  $SCRIPT_NAME -t backup --vault -s path/to/secret

	Use secret from vault and set ip:
	  $SCRIPT_NAME -t backup --vault --vault-addr 10.0.0.10 -s path/to/secret
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
	elif [ ! -z "$PASS" ];then
		create_temp_conf
	fi

	# Test that backup directory exists. Otherwise create it.
	local SRC="$OUTDIR/tmp"
	[ ! -e $SRC ] && mkdir -p $SRC

	echo "Start dumping DB $DB..."

	# Run mydumper with maximum available threads and with user
	# defined option.

	# This is a compatibility layer or debian 10. Mydumper in version 0.9.1
	# does not support option `--defaults-file`. So we can only apply that
	# option, when debian >= 10.
	mydumper $DEFAULTS_FILE \
		--database=$DB \
		--host=$HOST \
		--outputdir="$OUTDIR/tmp" \
		--threads="$MAX_THREADS"

	check_prev_exitcode $? "Error while backup"

	# Define some local vars to archive the SQL-dump. mydumper seperates
	# all dumps in one file per table. After archiving the files we got
	# all dumps in the same place sorted by date.If NFS_PATH is defined
	# we will also keep a backup on NFS mount and delete tmp dir.
	echo "Run archiving..."

	local EXTENS="_dump.tar.gz"
	local TAR_ARCHIVE="$OUTDIR/${DATE}_${DB}_${HOST}_$EXTENS"
	TMP_ARCHIVE=$TAR_ARCHIVE

	tar Pcfz "$TAR_ARCHIVE" -C $SRC .

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
	check_prev_exitcode $? "Cant count backups"

	if [ "$MAX_BACKUPS" != "" ];then
		while (( CURR_BACKUPS > MAX_BACKUPS ));do

			echo "Maximum number of backups reached($CURR_BACKUPS/$MAX_BACKUPS)."
			OLDEST_BACKUP=$(find "$OUTDIR" -type f -printf '%T+ %p\n' | sort | head -n 1 | awk '{print $2}')
			check_prev_exitcode $? "Cant find oldest backup"

			echo "Delete oldest Backup: $OLDEST_BACKUP"
			rm "$OLDEST_BACKUP"
			check_prev_exitcode $? "Cant delete oldest backup"

			CURR_BACKUPS=$(ls $OUTDIR | wc -l)
			check_prev_exitcode $? "Cant count backups"

		done
	fi
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

	tar xfvz $DUMPFILE
	check_prev_exitcode $? "Error while extracting archive"

	echo "DEBUG FORCE: $FORCE"
	if [ $FORCE -eq $TRUE ]; then
		myloader $DEFAULTS_FILE \
		--database=$DB \
		--host=$HOST \
		--user=$USER \
		--password="$PASS" \
		--directory="$DIR_TMP" \
		--threads="$MAX_THREADS" \
		--overwrite-tables \
		--verbose=3
	else
		myloader $DEFAULTS_FILE \
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

	TMPFILE="$TMPFILE_PATH"
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
	if [ "$isVaultUsed" == "$FALSE" ] && [ "$isPassEnabled" == "$FALSE" ] && [ "$PASS" == "" ];then
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
	if [ "$exitCode" -ne 0 ];then
		echo "$message"
		exit_on_failure
	fi
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
# FUNCTION:     housekeeping
# ARGUMENTS:    none
# RETURN:       void/null
# EXPLAIN:      This func removes temp. files on the system
# -----------------------------------------------------------------------------
housekeeping() {

	# Remove lockfile, so that the script
	# can be executed
	rm "$LOCKFILE"

	# Remove temporary created files
	rm -rf "$OUTDIR/tmp"

	# Remove temp recover dir
	rm -rf /tmp/recv/

	# Remove temp mysql config file
	rm -f "$HOME/.my.cnf"
}
# -----------------------------------------------------------------------------
# FUNCTION:     exit_on_failure
# ARGUMENTS:    none
# RETURN:       void/null
# EXPLAIN:      This func reads the Password of the DB
#               via API.
# -----------------------------------------------------------------------------
exit_on_failure() {

    # A maximum number of backups are specified
    # by MAX_BACKUPS. If the script would keep
    # broken backup files, the number of backups
    # would grow without having consistent backups.
    [ ! -z "$TMP_ARCHIVE" ] && rm -f "$TMP_ARCHIVE"

	# Execute housekeeping job
	housekeeping

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
	PASS=$(curl -s \
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
		--config-file)
			TMPFILE_PATH="$2"
			;;

	esac
	shift
done

# Extends lock file name with DB name
LOCKFILE="/tmp/${SCRIPT_NAME}-${DB}.lock"

# -----------------------------------------------------------------------------
# Run this script only if no lockfile exist or lockfile exists but the PID
# which we grep is no longer running.If the PID is running, it needs to match
# the SCRIPT_NAME var. Otherwise the PID is occupied by a new process. This
# could happen on systems that are heavily used.
# -----------------------------------------------------------------------------
if [ -e "$LOCKFILE" ]; then
	old_pid="$(< $LOCKFILE)"
	if [[ "$(ps -p $old_pid -o comm=)" =~ "backup_restore_" ]]; then
		echo "An process of this script is already running. Quit now"
		exit  1
	else
		echo "$PID" > "$LOCKFILE"
	fi
else
	echo "$PID" > "$LOCKFILE"
fi

# Debian 10 compatibility layer mydumper
if [ $(perl -e "if( `lsb_release -sr` < 10.0){print 1}") ];then
	echo "[!] INFO: Mydumper is started in compatibility mode for Debian 10..."
	DEFAULTS_FILE=""
else
	DEFAULTS_FILE="--defaults-file=$TMPFILE_PATH \\"
fi

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

