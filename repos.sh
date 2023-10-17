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

    #create file for logging user actions
    touch "$MAIN_DIR/$GIP_DIR/log"
    log "$USER created project repository, and is now administrator of the project"

    #create workspace area
    mkdir "$WORKSPACES_DIR"
    mkdir "$WORKSPACES_DIR/$USER"

    echo "Project repository is successfully initialised"

    #change security permissions to only allow the administrator write permissions
    chmod 755 "$GIP_DIR"
}

#takes in one parameter as input and appends it to the log file on a new line with a timestamp
function log() {
    local timestamp=$(date +"%Y-%m-%d %T")
    local log_file="$GIP_DIR/log"
    echo -e "$timestamp: $1\n" >> "$log_file"
}

function show_logs() {
    local log_file="$GIP_DIR/log"
    cat "$log_file"
}

function show_repo() {
    local repo_name=$(basename $PWD)
    echo -e "Project repository: $repo_name"
    echo "---------------------"
    echo "Repository folder:"
    find . -type f -not -path '*/\.*' -not -path './workspaces/*' | sed -n 's/^\.\// * /p' | sort
    echo "---------------------"
}

#takes a file name as input and either commits the changes you've made to said file in your directory and unlocks
#it's usage for others or it creates a blank file in the project directory
function checkin_file() {
    local file_name="$1"
    local newfile=$2
    local message="$3"
    #if file doesn't exist, inform the user or create it if a flag has been passed to create a file
    if [ ! -e $file_name ]; then
        if [ $newfile -eq 0 ]; then
            touch $file_name;
            if [[ -z "$message" ]]; then
                log "$USER has checked in new file '$file_name'"
            else
                log "$USER has checked in new file '$file_name'\nCommit message: '$message'"
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

#if a user needs a file for a program but does not want to check it out for editing
#they can use gip link to have a link to the file in their workspace
#takes a file name as input and links it to the calling user's workspace
function pull() {
	#if the file doesn't exist, cannot link to it
	if [ ! -e $1 ]; then
	    echo "File '$1' not found and cannot link to it"
	    return 1
	fi

	#if a link already exists, cannot link to it
	if [ -h "$WORKSPACES_DIR/$USER/$1" ]; then
	    echo "Link already exists in your workspace"
	    return 1
	fi

	ln "./$1" "$WORKSPACES_DIR/$USER/$1"
}

#takes in one input in the form of a filename and tries to remove that file
function remove() {
    local file_name="$1"
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

    rm $file_name
    if [ $# -eq 3 ]; then
        log "File '$file_name' has been removed by $USER\nCommit message: '$3'"
    else
        log "File '$file_name' has been removed by $USER"
    fi
}


function checkout_file() {
    local lock_file="$GIP_DIR/locks/$1.lock"

    # If file does not exist tell the user
    if [ ! -e $1 ]; then
	    echo "File '$1' does not exist in project directory"
	    return 1
    fi
    
    if [ -e "$lock_file" ]; then
	    local result=$(ls -l $GIP_DIR/locks/ | grep ".*$1\.lock$" | cut -d " " -f 3)
	    echo "File '$1' is already being edited by $result"
	    return 1
    fi
    # Create the lock file to indicate that the file is being edited and make a copy in the users workspace
    touch "$lock_file"
    echo $USER > $lock_file
    
    if [ -h "$WORKSPACES_DIR/$USER/$1" ]; then
	    rm "$WORKSPACES_DIR/$USER/$1"
    fi
    
    cp $1 "$WORKSPACES_DIR/$USER/$1"
    if [ $# -eq 3 ]; then
        log "$USER has checked out '$1' for editing\nCommit message: '$3'"
    else
        log "$USER has checked out '$1' for editing."
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


#This may be completely atypical to the rest of the design but bear with me (I secretly do not know what I'm doing)
#File name given as variable $3, path as $2
function import() {
    echo "Importing file $3 from filepath $2"
    #If file already exists in working repository
    if [[ -e "$3" ]]; then
        echo "A file of that name already exists in the project directory"
    #Check if file exists, if so, copy file to project directory
    elif [[ -e "$2/$3" ]]; then
        cp $3 ./
    else
        echo "The file '$3' cannot be found in the file system"
    fi
}

if [ "$1" = "init" ]; then
    init
    exit 0
fi

if ! [ -d $GIP_DIR ]; then
    echo "this is not a project root directory, move to the root directory of a project or use git init to initialise this directory"
    exit 0
fi

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
            shift 2
            while getopts "cm:" opt; do
                case ${opt} in
                    c )
                        newfile=0
                    ;;
                    m )
                        message="${OPTARG}"
                    ;;
                    \? )
                        echo "Invalid option: -${OPTARG}" >&2;;
                esac
            done
            checkin_file "$file_name" "$newfile" "$message"
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
            echo "Usage: gip remove <file_name> [-m <message>]"
        else
            remove "$2" "$3" "$4"
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
    *)
        echo "Usage: gip <command>"
        echo "Commands:"
        echo "  init                 Initialize the main directory for repositories"
        echo "  checkout <file_name> Checkout a file from the main directory to your workspace"
        echo "  checkin  <file_name> Check in a file from your workspace to the main directory"
        echo "  import   <file_path> <file_name> Import a pre-existing file to the working directory"
        echo "  remove   <file_name> Remove a currently non-checked out file";;
esac