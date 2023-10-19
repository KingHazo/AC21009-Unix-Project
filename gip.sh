#!/bin/bash

#this file is designed in a manner to either be called from a PATH variable directory or by absolute path to have a user keep only one
#copy of the file and allow the creation project folders on the fly without having to copy this file into them

#in order to handle permissions in the system we will only allow the initialising user, and so the admin of the project
#to perform actions like remove the .gip directory or load up a past archive

MAIN_DIR="."
WORKSPACES_DIR="$MAIN_DIR/workspaces"
GIP_DIR="$MAIN_DIR/.gip"

function init() {
    # Check if the metadata directory already exists
    if [ -d "$GIP_DIR" ]; then
        echo "Project folder is already initialised"
  	    return 0
    fi

    # Create the metadata directories
    mkdir -p "$GIP_DIR"
    mkdir -p "$GIP_DIR/locks"
    mkdir -p "$GIP_DIR/archives"

    # Create file for logging user actions
    touch "$MAIN_DIR/$GIP_DIR/log"
    log "$USER created project repository, and is now administrator of the project"

    # Create workspace area
    mkdir "$WORKSPACES_DIR"
    mkdir "$WORKSPACES_DIR/$USER"

    echo "Project repository is successfully initialised"
    archive

    # Change security permissions to only allow the administrator write permissions
    chmod 755 "$GIP_DIR"
}

# Takes in one parameter as input and appends it to the log file on a new line with a timestamp
function log() {
    local timestamp=$(date +"%Y-%m-%d %T")
    local log_file="$GIP_DIR/log"
    echo -e "$timestamp: $1\n" >> "$log_file"
}
# Showcases the log file's contents
function show_logs() {
    local log_file="$GIP_DIR/log"
    cat "$log_file"
}
#Showcases repository structure
function show_repo() {
    local repo_name=$(basename $PWD)
    echo -e "Project repository: $repo_name"
    echo "---------------------"
    echo "Repository folder:"
    find . -type f -not -path '*/\.*' -not -path './workspaces/*' | sed -n 's/^\.\// * /p' | sort
    echo "---------------------"
}

#if a user needs a file for a program but does not want to check it out for editing
#they can use gip link to have a link to the file in their workspace
#takes a file name as input and links it to the calling user's workspace
function pull() {
    local file_name="$1"
	#if the file doesn't exist, cannot link to it
	if [ ! -e $file_name ]; then
	    echo "File '$file_name' not found and cannot link to it"
	    return 1
	fi

	#if a link already exists, cannot link to it
	if [ -h "$WORKSPACES_DIR/$USER/$file_name" ]; then
	    echo "Link already exists in your workspace"
	    return 1
	fi

	 if ! ln "./$file_name" "$WORKSPACES_DIR/$USER/$file_name" 2>/dev/null; then
        echo "File '$file_name' already exists in your workspace"
    fi
}

# helper function to delete a file
function delete_file() {
    local file_name="$1"
    local message="$2"
    archive
    rm $file_name
    if [[ -z "$message" ]]; then
        log "$USER has removed '$file_name'"
    else
        log "$USER has removed '$file_name'\nCommit message: '$message'"
    fi
}

#takes in one input in the form of a filename and tries to remove that file
function remove() {
    local file_name="$1"
    local force="$2"
    local message="$3"
    #if the file is currently checked out, abort
    local lock_file="$GIP_DIR/locks/$file_name.lock"

    if [ -f $lock_file ]; then
	    local result=$(ls -l $GIP_DIR/locks/ | grep ".*$file_name\.lock$" | cut -d " " -f 3)
	    echo "File '$file_name' is currently being edited by $result and thus cannot be removed"
        return 1
    fi

    #if the file does not exist, cannot erase if
    if [ ! -e $file_name ]; then
	    echo "File '$file_name' does not exist"
        return 1
    fi

    if [ $force -eq 1 ]; then
        read -p "Are you sure you want to remove '$file_name'? (y/n) " answer
        if [ "$answer" = "y" ]; then
            delete_file "$file_name" "$message"
        fi
        return 0
    fi

    delete_file "$file_name" "$message"
}

#Identifies a file within the directory, if it exists it will create a lock file and make a copy of the file to the user's workspace
function checkout_file() {
    local file_name="$1"
    local lock_file="$GIP_DIR/locks/$file_name.lock"
    # If file does not exist tell the user
    if [ ! -e $file_name ]; then
	    echo "File '$file_name' does not exist in project directory"
	    return 1
    fi

    if [ -e "$lock_file" ]; then
	    local result=$(ls -l $GIP_DIR/locks/ | grep ".*$file_name\.lock$" | cut -d " " -f 3)
	    echo "File '$file_name' is already being edited by $result"
	    return 1
    fi

    archive
    # Create the lock file to indicate that the file is being edited and make a copy in the users workspace
    touch "$lock_file"
    echo $USER > $lock_file

    if [ -h "$WORKSPACES_DIR/$USER/$file_name" ]; then
	    rm "$WORKSPACES_DIR/$USER/$file_name"
    fi

    cp "$file_name" "$WORKSPACES_DIR/$USER/$file_name" 2>/dev/null
    if [ $# -eq 3 ]; then
        log "$USER has checked out '$file_name' for editing\nCommit message: '$3'"
    else
        log "$USER has checked out '$file_name' for editing."
    fi
}

#takes a file name as input and either commits the changes you've made to said file in your directory and unlocks
#it's usage for others or it creates a blank file in the project directory
function checkin_file() {
    local file_name="$1"
    local newfile="$2"
    local message="$3"
    #if file doesn't exist, inform the user or create it if a flag has been passed to create a file
    if [ ! -e "$file_name" ]; then
        if [ $newfile -eq 0 ]; then
            archive
            touch $file_name;
            if [[ -z "$message" ]]; then
                log "$USER has checked in new file '$file_name'"
            else
                log "$USER has checked in new file '$file_name'\nCommit message: '$message'"
            fi
            return 0
        fi

        if [ -f "$WORKSPACES_DIR/$USER/$file_name" ]; then
            archive
            mv "$WORKSPACES_DIR/$USER/$file_name" "./$file_name"
            changes=$(cat "$file_name")
            if [[ -z "$message" ]]; then
                log "$USER has checked in '$file_name' after making changes:\n$changes"
            else
                log "$USER has checked in '$file_name' after making changes:\n> $changes\nCommit message: '$message'"
            fi
            return 0
        fi


        echo "File '$file_name' does not exist"
        return 0
    fi

    #check for a lock file, if it does not exist the file is not checked out and cannot be checked in
    #first we will disable the lock, and then copy the file into the main project directory to overwrite the differences
    #and lastly create links to the file in each persons working directory to reflect the differences in other users workspaces
    local lock_file="$GIP_DIR/locks/$file_name.lock"
    if [ -e "$lock_file" ]; then
	    if [ ! "$(cat $lock_file)" = $USER ]; then
	        echo "File is checked out by a different user"
        fi
        # Remove the lock file to indicate that the file is no longer being edited
        archive
        rm "$lock_file"
	    changes=$(diff -B $file_name "$WORKSPACES_DIR/$USER/$file_name" | tail -n +2 | grep -v "No newline at end of file")
	    mv "$WORKSPACES_DIR/$USER/$file_name" "./$file_name"
        if [[ -z "$message" ]]; then
            log "$USER has checked in '$file_name' after making changes:\n$changes"
        else
            log "$USER has checked in '$file_name' after making changes:\n$changes\nCommit message: '$message'"
        fi
    else
        echo "File '$file_name' is not checked out"
    fi
}

# In-script text editing
function edit_file() {
    local file_name="$1"
    cd "$WORKSPACES_DIR/$USER"
    if [ ! -e "$file_name" ]; then
        echo "File '$file_name' does not exist in your workspace. Please use gip pull to pull the file from the project directory."
        return 1
    fi
    nano "$file_name"
}

function archive() {
    local timestamp=$(date +"%Y-%m-%d %T")
    local archive_name="$GIP_DIR/archives/$timestamp"
    if zip -r -y "$archive_name" "$MAIN_DIR" -x "$GIP_DIR/*" -x "$WORKSPACES_DIR/*" > /dev/null; then
        log "$USER has archived the project repository under the following archive name: '$(basename "$archive_name.zip")'"
    fi
}

function show_archives() {
    local archives="$GIP_DIR/archives"
    cd "$archives"
    echo "Archives:"
    ls | sed 's/^/* /' | sort
    echo "---------------------"
}

# Revert changes based on archived files
function revert() {
    # revert to latest archive
    local archive_name=""
    if [ "$1" = "-l" ]; then
        archive_name=$(ls -t "$GIP_DIR/archives" | head -n 1)
    else
        archive_name="$1"
    fi
    local archive_path="$GIP_DIR/archives/$archive_name"
    if [ ! -e "$archive_path" ]; then
        echo "Archive '$archive_name' does not exist"
        return 1
    fi
    archive
    find . -type f -not -path '*/\.*' -not -path './workspaces/*' -delete
    unzip "$archive_path" -d "$MAIN_DIR" > /dev/null
    log "$USER has reverted the project repository to the following version: '$archive_name'"
    echo "Project repository has been reverted to the following version: '${archive_name%.*}'"
}

#Imports a desired file, if given the file path to the file and the name of the file
function import() {
    local file_path="$1"
    local file_name="$2"
    echo "Importing file $file_name from filepath $file_path"
    #If file already exists in working repository
    if [[ -e "$file_name" ]]; then
        echo "A file of that name already exists in the project directory"
    #Check if file exists, if so, copy file to project directory
    elif [[ -e "$file_path/$file_name" ]]; then
        archive
        cp $file_name ./
    else
        echo "The file '$file_name' cannot be found in the file system"
    fi
}

function help() {
    echo "Thank you for using Gip!"
    echo "Our commands are as follows:"
    echo "----------------------------"
    echo "Usage: gip <command>"
    echo "Commands:"
    echo "  init                 Initialize the main directory for repositories"
    echo "  checkout <file_name> [-m <message>]  Checkout a file from the main directory to your workspace"
    echo "  checkin  <file_name> [-c] [-m <message>] Check in a file from your workspace to the main directory"
    echo "  import   <file_path> <file_name> Import a pre-existing file to the workspace"
    echo "  edit     <file_name> Opens the file in Visual Studio Code"
    echo "  remove   <file_name> [-m <message>] Remove a currently non-checked out file"
    echo "  pull     <file_name> Pulls the most recent files in the main directory to your workspace"
    echo "  archives             Shows the archives to the user"
    echo "  show                 Shows the repository structure to the user"
    echo "  logs                 Prints the contents of the log file"
    echo "  revert   <archive_name> [-l] Reverts the changes created in workspace to most recent archive"
    echo "  help                 Prints this text block"

}
#Statement to check initialisation
if [ "$1" = "init" ]; then
    init
    exit 0
fi

if ! [ -d $GIP_DIR ]; then
    echo "this is not a project root directory, move to the root directory of a project or use git init to initialise this directory"
    exit 0
fi
#Case statement to check for gip commands
case $1 in
    "checkout")
        if [ $# -lt 2 ]; then
            echo "Usage: gip checkout <file_name> [-m <message>]"
        else
            checkout_file "$2" "$3" "$4"
        fi;;
    "checkin")
        if [ $# -lt 2 ]; then
            echo "Usage: gip checkin <file_name> [-c] [-m <message>]"
        else
            file_name="$2"
            newfile=1
            message=""
            valid=0
            shift 2
            while getopts "cm:" opt; do
                case ${opt} in
                    c )
                        newfile=0 ;;
                    m )
                        message="${OPTARG}" ;;
                    \? )
                        valid=1
                        echo "Invalid option!" >&2;;
                esac
            done
            if [ $valid -eq 0 ]; then
                checkin_file "$file_name" "$newfile" "$message"
            fi
        fi;;
    "edit")
        if [ $# -lt 2 ]; then
            echo "Usage: gip edit <file_name>"
        else
            edit_file "$2"
        fi;;
    "import")
	    if [ $# -lt 3 ]; then
	        echo "Usage: gip import <file_path> <file_name>"
        else
            import "$2" "$3"
        fi;;
    "remove")
        if [ $# -lt 2 ]; then
            echo "Usage: gip remove <file_name> [-f] [-m <message>]"
        else
            file_name="$2"
            force=1
            message=""
            valid=0
            shift 2
            while getopts "fm:" opt; do
                case ${opt} in
                    f )
                        force=0 ;;
                    m )
                        message="${OPTARG}" ;;
                    \? )
                        valid=1
                        echo "Invalid option!" >&2;;
                esac
            done
            if [ $valid -eq 0 ]; then
                remove "$file_name" "$force" "$message"
            fi        
        fi;;
    "pull")
        if [ $# -lt 2 ]; then
            echo "Usage: gip pull <file_name>"
        else
            pull "$2"
        fi;;
    "logs")
        show_logs;;
    "show")
        show_repo;;
    "archives")
        show_archives;;
    "revert")
        if [ $# -lt 2 ]; then
            echo "Usage: gip revert <archive_name> [-l]"
        else
            revert "$2"
        fi;;
    "help")
        help;;
    *)
        echo "Usage: gip <command>"
        echo "Commands:"
        echo "  init                 Initialize the main directory for repositories"
        echo "  checkout <file_name> [-m <message>]  Checkout a file from the main directory to your workspace"
        echo "  checkin  <file_name> [-c] [-m <message>] Check in a file from your workspace to the main directory"
        echo "  import   <file_path> <file_name> Import a pre-existing file to the workspace"
        echo "  edit     <file_name> Opens the file in Visual Studio Code"
        echo "  remove   <file_name> [-f] [-m <message>] Remove a currently non-checked out file"
        echo "  pull     <file_name> Pulls the most recent files in the main directory to your workspace"
        echo "  archives             Shows the archives to the user"
        echo "  show                 Shows the repository structure to the user"
        echo "  logs                 Prints the contents of the log file"
        echo "  revert   <archive_name> [-l] Reverts the changes created in workspace to most recent archive"
        echo "  help                 Prints this text block";;
esac
