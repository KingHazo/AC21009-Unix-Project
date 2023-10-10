#!/bin/bash

#this file should be in a path variable directory so that it can be accessed from anywhere, only requires one
#copy of the file and allows the users to create project folders on the fly without having to copy this file into their
#project folder. For these reasons the idea of a global config file or directory sharing information on all the
#repositories as I assume you are implying through the implementation of the switch repo function is unnecessary
#as we only need to see if the user is in a project folder through checking if the current directory contains
#".gip" directory

function init() {
    # Check if the metadata directory already exists
    if [ -d "./.gip" ]; then
        echo "project folder is already initialised"
    else
        # Create the metadata directories
        mkdir "./.gip"
        mkdir "./.gip/logs"
        mkdir "./.gip/locks"

        touch "./.gip/global.config"
	touch "./.gip/filelist"
	touch "./.gip/fileCheckout"
        echo "project repository is initialised"

	#change security permission for root directory to not allow users to alter it without using gip
	chmod 555 ./
    fi
}

#instead of adding and removing files, we'll make the project directory inaccesible through direct means
#we'll add directories for users as workspaces and ask users the files they want to check out from the main directory
#to work on and make non-writable for others, if they add files in their workspace we'll make the files be added automatically
#to the project directory after they commit their changes and checkout the files

function log_file() {
    timestamp=$(date +"%Y-%m-%d %T")
    log_file=$GLOBAL_DIR/$CURRENT_REPO/.gip/logs/$timestamp.log
    echo "$3: '$1 ($timestamp)'" >> "$log_file"
    echo "Content: $2" >> "$log_file"
}

function checkout_file() {
    lock_file="$GLOBAL_DIR/$CURRENT_REPO/.gip/locks/$1.lock"

    if [ -e "$lock_file" ]; then
        echo "File '$1' is already being edited by another user."
    else
        # Create the lock file to indicate that the file is being edited
        touch "$lock_file"
        echo "User '$2' has checked out '$1' for editing."
    fi
}

function checkin_file() {
    lock_file="$GLOBAL_DIR/$repo_name/.gip/locks/$file_name.lock"
    if [ -e "$lock_file" ]; then
        # Remove the lock file to indicate that the file is no longer being edited
        rm "$lock_file"
        echo "User '$2' has checked in '$1' after editing"
    else
        echo "File '$1' is not being edited by user '$2'"
    fi
}

if [ "$1" = "init" ]; then
    init
    exit 0
fi

if ! [ -d "./.gip" ]; then
    echo "this is not a project root directory, move to the root directory of a project or use git init to initialise this directory"
    exit 0;
fi

case $1 in
    "create")
        if [ $# -lt 2 ]; then
            echo "Usage: ./repos.sh create <repository_name>"
        else
            create_repo "$2"
        fi;;
    "checkout")
        if [ -z "$CURRENT_REPO" ]; then
            echo "No repository created. Please run './repos.sh create <repository_name>' to create one"
        elif [ $# -lt 2 ]; then
            echo "Usage: ./repos.sh checkout <file_name>"
        else
            checkout_file "$2" "$3"
        fi;;
    "checkin")
        if [ -z "$CURRENT_REPO" ]; then
            echo "No repository created. Please run './repos.sh create <repository_name>' to create one"
        elif [ $# -lt 2 ]; then
            echo "Usage: ./repos.sh checkin <file_name>"
        else
            checkin_file "$2" "$3"
        fi;;
    "switch")
        if [ $# -lt 2 ]; then
            echo "Usage: ./repos.sh switch <repository_name>"
        elif [ $# -lt 2 ]; then
            switch_repo "$2"
        fi;;
    *)
        echo "Usage: ./repos.sh <command>"
        echo "Commands:"
        echo "  init                Initialize the main directory for repositories"
        echo "  create <repo_name>  Create a new repository with the specified name";;
esac
