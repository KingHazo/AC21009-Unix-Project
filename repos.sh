#!/bin/bash

#this file should be in a path variable directory so that it can be accessed from anywhere, only requires one
#copy of the file and allows the users to create project folders on the fly without having to copy this file into their 
#project folder. For these reasons the idea of a global config file or directory sharing information on all the 
#repositories as I assume you are implying through the implementation of the switch repo function is unnecessary
#as we only need to see if the user is in a project folder through checking if the current directory contains 
#".gib" directory 

function init() {
    # Check if the metadata directory already exists
    if [ -d "./.gib" ]; then
        echo "project folder is already initialised"
    else
        # Create the metadata directories
        mkdir "./.gib"
        mkdir "./.gip/logs"
        mkdir "./.gip/locks"

        touch "./.gib/global.config"
        echo "project repository is initialised"
    fi    
}   

function switch_repo() {
    repo_name="$1"
    repo_path="$GLOBAL_DIR/$repo_name"

    # Check if the repository directory exists
    if [ -d "$repo_path" ]; then
        CURRENT_REPO="$repo_name"
        echo "$repo_name" > "$GLOBAL_DIR/global.config"
        echo "Working repository set to '$repo_name'."
    else
        echo "Repository '$repo_name' does not exist."
    fi
}

function add_file() {
    file_name="$1"
    content="$2"
    file_path="$GLOBAL_DIR/$CURRENT_REPO/$file_name"

    # Check if the file already exists
    if [ -f "$file_path" ]; then
        echo "File '$file_name' already exists."
    else
        # Create the file
        touch "$file_path"
        echo "$content" > "$file_path"
        log_file "$file_name" "$content" "Added"
        echo "File '$1' created."
    fi
}

function remove_file() {
    file_name="$1"
    file_path="$GLOBAL_DIR/$CURRENT_REPO/$file_name"

    # Check if the file exists
    if [ -f "$file_path" ]; then
        rm "$file_path"
        log_file "$file_name" "" "Removed"
        echo "File '$file_name' removed."
    else
        echo "File '$file_name' does not exist."
    fi
}

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


# function create_branch() {
#     branch_name="$1"
#     branch_path="$GLOBAL_DIR/$CURRENT_REPO/.gip/branches/$branch_name"

#     # Check if the branch already exists
#     if [ -d "$branch_path" ]; then
#         echo "Branch '$branch_name' already exists."
#     else
#         # Create the branch directory structure
#         mkdir -p "$branch_path/.gip"
#         mkdir -p "$branch_path/.gip/branches"

#         # Store branch information in a config file
#         echo "$branch_name" > "$GLOBAL_DIR/$CURRENT_REPO/.gip/branches.config"
#         echo "Branch '$branch_name' created."
#     fi
# }

# function switch_branch() {
#     branch_name="$1"
#     branch_path="$GLOBAL_DIR/$CURRENT_REPO/.gip/branches/$branch_name"

#     # Check if the branch directory exists
#     if [ -d "$branch_path" ]; then
#         CURRENT_BRANCH="$branch_name"
#         echo "$branch_name" > "$GLOBAL_DIR/$CURRENT_REPO/.gip/branches.config"
#         echo "Working branch set to '$branch_name'."
#     else
#         echo "Branch '$branch_name' does not exist."
#     fi
# }

if [ "$1" = "init" ]; then
    init
    exit 0
fi

if ! [ -d "$GLOBAL_DIR" ]; then
    echo "Main directory 'global' does not exist. Please run './repos.sh init' to create it"
    exit 0;
fi

case $1 in 
    "create")
        if [ $# -lt 2 ]; then
            echo "Usage: ./repos.sh create <repository_name>"
        else
            create_repo "$2"
        fi;;
    "add")
        if [ -z "$CURRENT_REPO" ]; then
            echo "No repository created. Please run './repos.sh create <repository_name>' to create one"
        elif [ $# -lt 2 ]; then
            echo "Usage: ./repos.sh add <file_name>"
        elif [ ! -f "$2" ] && [ "$3" != "-e" ]; then
            echo "File '$2' does not exist."
        else
            content=""
            if [ "$3" != "-e" ]; then
                content=$(cat "$2")
            fi
            add_file "$2" "$content"
        fi;;
    "remove")
        if [ -z "$CURRENT_REPO" ]; then
            echo "No repository created. Please run './repos.sh create <repository_name>' to create one"
        elif [ $# -lt 2 ]; then
            echo "Usage: ./repos.sh remove <file_name>"
        else
            remove_file "$2"
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
