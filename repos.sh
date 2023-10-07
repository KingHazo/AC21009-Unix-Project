#!/bin/bash

WORK_DIR=$(pwd)
GLOBAL_DIR=$WORK_DIR/global
if [ -f "$GLOBAL_DIR/global.config" ]; then
    CONFIG_FILE="$GLOBAL_DIR/global.config"
    CURRENT_REPO=$(cat "$CONFIG_FILE")
fi

function init() {
    # Check if the main directory already exists
    main_dir="$WORK_DIR/global"
    if [ -d "$main_dir" ]; then
        echo "Main directory 'global' already exists"
    else
        # Create the main directory
        mkdir -p "$main_dir"
        touch "$main_dir/global.config"
        echo "Main directory 'global' created"
    fi
}

function create_repo() {
    repo_name="$1"
    # Check if the main directory exists
    repo_path="$GLOBAL_DIR/$repo_name"

    # Check if the repository already exists
    if [ -d "$repo_path" ]; then
        echo "Repository '$repo_name' already exists."
    else
        # Create the repository directory structure
        mkdir -p "$repo_path/.gip/logs"
        mkdir -p "$repo_path/.gip/locks"
        CURRENT_REPO="$repo_name"

        # Store repository information in a config file
        echo "$repo_name" > "$GLOBAL_DIR/global.config"
        echo "Repository '$repo_name' created."
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
else
    if ! [ -d "$GLOBAL_DIR" ]; then
        echo "Main directory 'global' does not exist. Please run './repos.sh init' to create it"
    else 
        if [ "$1" = "create" ]; then
            if [ $# -lt 2 ]; then
                echo "Usage: ./repos.sh create <repository_name>"
            else
                create_repo "$2"
            fi
        elif [ "$1" = "add" ]; then
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
            fi
        elif [ "$1" = "remove" ]; then
            if [ -z "$CURRENT_REPO" ]; then
                echo "No repository created. Please run './repos.sh create <repository_name>' to create one"
            elif [ $# -lt 2 ]; then
                echo "Usage: ./repos.sh remove <file_name>"
            else
                remove_file "$2"
            fi
        elif [ "$1" = "checkout" ]; then
            if [ -z "$CURRENT_REPO" ]; then
                echo "No repository created. Please run './repos.sh create <repository_name>' to create one"
            elif [ $# -lt 2 ]; then
                echo "Usage: ./repos.sh checkout <file_name>"
            else
                checkout_file "$2" "$3"
            fi
        elif [ "$1" = "checkin" ]; then
            if [ -z "$CURRENT_REPO" ]; then
                echo "No repository created. Please run './repos.sh create <repository_name>' to create one"
            elif [ $# -lt 2 ]; then
                echo "Usage: ./repos.sh checkin <file_name>"
            else
                checkin_file "$2" "$3"
            fi
        elif [ "$1" = "switch" ]; then
            if [ $# -lt 2 ]; then
                echo "Usage: ./repos.sh switch <repository_name>"
            else
                switch_repo "$2"
            fi
        else
            echo "Usage: ./repos.sh <command>"
            echo "Commands:"
            echo "  init                Initialize the main directory for repositories"
            echo "  create <repo_name>  Create a new repository with the specified name"
        fi
    fi        
fi

