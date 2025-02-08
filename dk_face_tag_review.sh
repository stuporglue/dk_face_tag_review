#!/bin/bash

### MIT License Copyright (c) 2025 Michael Moore <stuporglue@gmail.com>
### 
### Permission is hereby granted, free of charge, to any person obtaining a copy
### of this software and associated documentation files (the "Software"), to deal
### in the Software without restriction, including without limitation the rights
### to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
### copies of the Software, and to permit persons to whom the Software is furnished
### to do so, subject to the following conditions:
### 
### The above copyright notice and this permission notice (including the next
### paragraph) shall be included in all copies or substantial portions of the
### Software.
### 
### THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
### IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
### FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
### OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
### WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
### OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Check for the config file and some db connection parameter sanity
startup() {

	TAG_NAME="DK Face Tag Review"

	if [ ! -f ~/.config/digikamrc ]; then
		echo -n "I don't see a config file at '"
		echo -n ~/.config/digikamrc
		echo "' and I don't know what to do!"
		echo
		echo "For your safety, I am going to exit."
		exit
	fi

	dk_dbtype=$(grep 'Database Type=' ~/.config/digikamrc | sed 's/[^=]*=//')

	if ! [ "$dk_dbtype" = "QMYSQL" ]; then 
		echo "Your database type is not QMYSQL, it is '$dk_dbtype'"
		echo "which I don't know how to handle."
		echo
		echo "For your safety, I am going to exit."
		exit
	fi

	dk_dbuser=$(grep 'Database Username=' ~/.config/digikamrc | sed 's/[^=]*=//')
	dk_dbhost=$(grep 'Database Hostname=' ~/.config/digikamrc | sed 's/[^=]*=//')
	dk_dbname=$(grep 'Database Name=' ~/.config/digikamrc | sed 's/[^=]*=//')
	dk_dbport=$(grep 'Database Port=' ~/.config/digikamrc | sed 's/[^=]*=//')

	if [ "$dk_dbuser" = "" -o "$dk_dbhost" = "" -o "$dk_dbname" = "" -o "$dk_dbport" = "" ]; then
		echo "Your digikamrc doesn't seem to have all the DB credentials."
		echo "This script is only tested to work with MySQL (MariaDB) on Linux."
		echo
		echo "For your safety, I am going to exit."
		exit
	fi

	HAS_COLUMN="Unknown"
	HAS_TAG="Unknown"
	FIRST_TAG_DATE="Unknown"
	TOTAL_MARKABLE="Unknown"
	TOTAL_MARKED="Unknown"

	# A little nicer interface, if we can
	if [ -x "$(command -v tput)" ]; then
		bold=$(tput bold)
		underline=$(tput smul)
		normal=$(tput sgr0)
	else 
		bold=""
		underline=""
		normal=""
	fi
}

get_sql_password() {
	echo
	echo "In order to connect to digiKam's database, I will need your database password"
	read -s -p "Enter MySQL Password for '$dk_dbuser@$dk_dbhost:$dk_dbport/$dk_dbname' > " dk_dbpass
	echo
}


# Run an SQL command. Handles authentication and asks the user before running anything
sql_command() {

	if [ "$dk_dbpass" = "" ]; then
		get_sql_password
	fi

	sql="$1"

	# If Mysql sees "localhost" it tries to connect on a socket, unless the port is also specified
	# in which case it makes a network connection. 
	# To force a network connection, you should use 127.0.0.1 instead. 
	# Sources: https://stackoverflow.com/questions/5376427/cant-connect-to-local-mysql-server-through-socket-var-mysql-mysql-sock-38 etc.
	if [ "$dk_dbport" = "3306" -a "$dk_dbhost" = "localhost" ]; then
		cmd="mysql -vv --user=${dk_dbuser:Q} --host=${dk_dbhost:Q} --password=${dk_dbpass:Q} --database=${dk_dbname:Q}"
	else
		cmd="mysql -vv --user=${dk_dbuser:Q} --port=${dk_dbport:Q} --host=${dk_dbhost:Q} --password=${dk_dbpass:Q} --database=${dk_dbname:Q}"
	fi

	echo "Using SQL command: $cmd"

	echo "I am about to run the query: "
	echo
	echo "$sql" 
	echo
	read -p "Should I continue? (y/N) " CONT
	echo

	if [ "$CONT" = "y" ]; then
		echo "$sql" | $cmd
	else 
		echo "Ok! Not running query"
	fi
}

check_info() {
	if [ "$dk_dbpass" = "" ]; then
		get_sql_password
	fi

	echo "I will run the following queries to see what the current status is:"
	echo
	echo "SHOW CREATE TABLE ImageTags"
	echo "SELECT COUNT(*) FROM Tags WHERE pid=0 AND name='$TAG_NAME'"
	echo "SELECT MIN(created_ts) FROM ImageTags"
	echo "SELECT MIN(created_ts) FROM ImageTags"
	echo "SELECT COUNT(DISTINCT imageid) AS ReviewableCount FROM ImageTags WHERE created_ts IS NOT NULL"
	echo "SELECT COUNT(*) AS TaggedForReview FROM ImageTags WHERE tagid=(SELECT id FROM Tags WHERE pid=0 AND name='$TAG_NAME')"

	echo
	read -p "Should I continue? (y/N) " CONT
	echo

	if ! [ "$CONT" = "y" ]; then
		echo "Ok! Not running query"
		return
	fi

	if [ "$dk_dbport" = "3306" -a "$dk_dbhost" = "localhost" ]; then
		cmd="mysql -s --user=${dk_dbuser:Q} --host=${dk_dbhost:Q} --password=${dk_dbpass:Q} --database=${dk_dbname:Q}"
	else
		cmd="mysql -s --user=${dk_dbuser:Q} --port=${dk_dbport:Q} --host=${dk_dbhost:Q} --password=${dk_dbpass:Q} --database=${dk_dbname:Q}"
	fi

	HAS_COLUMN=$(echo "SHOW CREATE TABLE ImageTags " | $cmd)
	if [[ "$HAS_COLUMN" == *"created_ts"* ]]; then
		HAS_COLUMN="1"
	else
		HAS_COLUMN="0"
	fi

	HAS_TAG=$(echo "SELECT COUNT(*) FROM Tags WHERE pid=0 AND name='$TAG_NAME'" | $cmd)

	if [ "$HAS_COLUMN" = "1" ]; then
		FIRST_TAG_DATE=$(echo "SELECT MIN(created_ts) FROM ImageTags" | $cmd)
	else
		FIRST_TAG_DATE="N/A"
	fi

	if [ "$HAS_COLUMN" = "1" ]; then
		TOTAL_MARKABLE=$(echo "SELECT COUNT(DISTINCT imageid) AS ReviewableCount FROM ImageTags WHERE created_ts IS NOT NULL" | $cmd);
	else
		TOTAL_MARKABLE="N/A"
	fi

	if [ "$HAS_TAG" = "1" ]; then 
		TOTAL_MARKED=$(echo "SELECT COUNT(*) AS TaggedForReview FROM ImageTags WHERE tagid=(SELECT id FROM Tags WHERE pid=0 AND name='$TAG_NAME')" | $cmd)
	else
		TOTAL_MARKED="0"
	fi
}

print_info() {

	check_info

	echo
	echo "${bold}Does the created_ts column exist?${normal}: $HAS_COLUMN"
	echo "${bold}Does the tag '$TAG_NAME' exist?${normal}: $HAS_TAG"
	echo "${bold}Earliest date we can mark?${normal}: $FIRST_TAG_DATE"
	echo "${bold}Total markable photos?${normal}: $TOTAL_MARKABLE"
	echo "${bold}Total photos currently marked?${normal}: $TOTAL_MARKED"
	echo

	read -p "Press Enter to continue" CONT


}

# Print the help text
print_help() {
	echo "
	${bold}${underline}DK Face Tag Review${normal}

	This is NOT an officially supported tool from digiKam. There
	are no guarantees or warranties of any kind. Using it might be DANGEROUS.

	${bold}PURPOSE${normal}: When tagging photos you might accidentally tag some 
	incorrectly. This tool adds a tag named '$TAG_NAME' to digiKam,
	and adds a new timestamp column named 'created_ts' to the ImageTags 
	table.  

	Any photos tagged after the column has been added will show the
	timestamp that the tag was applied. 

	This tool can then add the '$TAG_NAME' tag to the last N photos
	which had a People tag added, or all photos with a People tag 
	added in the last N minutes, hours or days. 

	${bold}REQUIREMENTS${normal}: You must be using MySQL as your database, on Linux. 
	The script gets the database settings (other than the password) 
	from your ~/.config/digikamrc file and asks you for your database
	password. You must also have the mysql command-line program installed.

	${bold}RISKS${normal}: Any time you access a program's database directly there is a
	risk of corrupting data or making mistakes. By using this program
	you assume those risks yourself. 

	${bold}SUPPORT${normal}: Please file a ticket on GitHub. Do not bother the digiKam
	developers with this, this is not their program and is unofficial.

	${bold}TESTED WITH${normal}: digiKam 8.6 weekly release appimage on Debian Linux 
	with MariaDB 11.4.4

	Press ENTER to continue
" | more
}

# Ask the user how many photos to mark for review and do it. 
# Adds the "$TAG_NAME" tag to those photos
mark_last_n() {
	read -p "How many of the most recent photos should I mark for review? [100] " REVIEW 

	if [ "$REVIEW" = "" ]; then
		REVIEW=100
	fi

	if ! [[ "$REVIEW" =~ ^[0-9]+$ ]]; then
		echo 
		echo "ERROR: '$REVIEW' is not an integer number. Not marking any photos."
		read -p "Press ENTER to start over" RESET 
		return
	fi

	sql_command "
	INSERT IGNORE INTO ImageTags (imageid,tagid) 
	SELECT DISTINCT i.id, (SELECT id FROM Tags WHERE pid=0 AND name='$TAG_NAME') 
	FROM 
		ImageTags it, 
		Images i, 
		Tags t, 
		Tags tp 
	WHERE 
	it.imageid=i.id 
	AND it.tagid=t.id 
	AND t.pid=tp.id 
	AND tp.name='People' 
	AND it.created_ts IS NOT NULL
	ORDER BY it.created_ts DESC 
	LIMIT $REVIEW"
}

# Asks the user which interval (m, h, d) and how many intervals to mark photos for
# Adds the "TAG_NAME" tag to those photos
mark_last_interval() {
	read -p "Do you want to mark photos for the last (m)inutes, (h)ours or (d)ays? [m] " INTERVAL

	if [ "$INTERVAL" = "m" -o "$INTERVAL" = "" ]; then
		INTERVAL="MINUTE"
		DURATION_DEFAULT=15
	elif [ "$INTERVAL" = "h" ]; then 
		INTERVAL="HOUR"
		DURATION_DEFAULT=1
	elif [ "$INTERVAL" = "d" ]; then
		INTERVAL="DAY"
		DURATION_DEFAULT=1
	else
		echo 
		echo "ERROR: '$INTERVAL' was not one of m,h or d. I don't know how to handle it."
		read -p "Press ENTER to start over" RESET
		return
	fi


	read -p "For how many of the last ${INTERVAL}(S) do you want to mark photos for review? [$DURATION_DEFAULT] " DURATION

	if [ "$DURATION" = "" ]; then
		DURATION=$DURATION_DEFAULT
	fi

	if ! [[ "$DURATION" =~ ^[0-9]+$ ]]; then
		echo 
		echo "ERROR: '$DURATION' is not an integer number. Not marking any photos."
		read -p "Press ENTER to start over" RESET
		return
	fi


 	sql_command "
 	INSERT IGNORE INTO ImageTags (imageid,tagid) 
 	SELECT DISTINCT i.id, (SELECT id FROM Tags WHERE pid=0 AND name='$TAG_NAME') 
 	FROM 
 		ImageTags it, 
 		Images i, 
 		Tags t, 
 		Tags tp 
 	WHERE 
 	it.imageid=i.id 
 	AND it.tagid=t.id 
 	AND t.pid=tp.id 
 	AND tp.name='People' 
 	AND it.created_ts IS NOT NULL
 	AND it.created_ts > DATE_SUB(now(), INTERVAL $DURATION $INTERVAL)"
}

# Removes the "$TAG_NAME" tag from all photos
unmark_all() {
	sql_command "DELETE FROM ImageTags WHERE tagid=(SELECT id FROM Tags WHERE pid=0 AND name='$TAG_NAME')"
}

# Adds the column and tag needed
setup_face_tag_review() {
	sql_command "ALTER TABLE ImageTags ADD COLUMN IF NOT EXISTS created_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP" 
	sql_command "INSERT IGNORE INTO Tags (pid,name) VALUES (0,'$TAG_NAME')"
}

# Removes the column and tag
remove_face_tag_review() {
	sql_command "ALTER TABLE ImageTags DROP COLUMN IF NOT EXISTS created_ts"
	sql_command "DELETE FROM Tags WHERE pid=0 AND name='$TAG_NAME'";
}

# Dump the dk database
backup_digikam() {

	if [ "$dk_dbpass" = "" ]; then
		get_sql_password
	fi

	OUTFILE="digikam_backup_"$(date +"%Y%m%d_%H%S")".sql"
	if [ "$dk_dbport" = "3306" -a "$dk_dbhost" = "localhost" ]; then
		# If Mysql sees "localhost" it tries to connect on a socket, unless the port is also specified
		# in which case it makes a network connection. 
		# To force a network connection, you should use 127.0.0.1 instead. 
		# Sources: https://stackoverflow.com/questions/5376427/cant-connect-to-local-mysql-server-through-socket-var-mysql-mysql-sock-38 etc.
		cmd="mysqldump -vv --user=${dk_dbuser:Q} --host=${dk_dbhost:Q} --password=${dk_dbpass:Q} --databases ${dk_dbname:Q}"
	else
		cmd="mysqldump -vv --user=${dk_dbuser:Q} --port=${dk_dbport:Q} --host=${dk_dbhost:Q} --password=${dk_dbpass:Q} --databases ${dk_dbname:Q}"
	fi

	echo "I am about to run: "
	echo "$cmd > $OUTFILE" 
	echo
	read -p "Should I continue? (y/N) " CONT
	echo

	if [ "$CONT" = "y" ]; then
		$cmd > "$OUTFILE"
	else 
		echo "Ok! Not running query"
	fi
}

# Do the startup sanity checks
startup

# Just keep looping until the user quits. 
while :
do

	echo
	echo "${bold}${underline}DK Face Tag Review${normal}"
	echo "${bold}h${normal}: Show More help"

	if ! [[ "$dk_dbpass" = "" ]]; then
		echo "${bold}m${normal}: Mark the last N photos tagged with a People tag for review"
		echo "${bold}t${normal}: Mark photos tagged with a People tag in the last N minutes, hours or days for review"
		echo "${bold}u${normal}: Unmark all photos marked for review"
		echo "${bold}s${normal}: Set up my Digikam MySQL database to use this tool"
		echo "${bold}r${normal}: Remove the extra column from my database"
		echo "${bold}b${normal}: Make a backup of my database"
	else
		echo "${bold}c${normal}: Connect to your database in order to see more options"
	fi
	echo "${bold}i${normal}: System status info"
	echo "${bold}q${normal}: Quit"
	echo

	if [[ "$dk_dbpass" = "" ]]; then
		read -p "What would you like to do? (h/c/i/q) " action
	else
		read -p "What would you like to do? (h/m/t/u/s/r/b/i/q) " action
	fi

	case $action in

		h) print_help ;;
		c) get_sql_password;;
		m) mark_last_n ;;
		t) mark_last_interval ;;
		u) unmark_all ;;
		s) setup_face_tag_review ;;
		r) remove_face_tag_review ;;
		i) print_info;;
		b) backup_digikam ;;
		q) exit ;;
	esac
done
