#!/bin/bash

WORK_DIR=$(pwd)
GLOBAL_DIR=$WORK_DIR/global
GIP_DIR=.gip
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
        mkdir -p "$repo_path/$GIP_DIR/logs"
        mkdir -p "$repo_path/$GIP_DIR/locks"
        CURRENT_REPO="$repo_name"

        # Store repository information in a config file
        echo "$repo_name" > "$GLOBAL_DIR/global.config"
        echo "Repository '$repo_name' created."
    fi
}

function delete_repo() {
    repo_name="$1"
    repo_path="$GLOBAL_DIR/$repo_name"

    # Check if the repository directory exists
    if [ -d "$repo_path" ]; then
        rm -rf "$repo_path"
        echo "Repository '$repo_name' deleted."
    else
        echo "Repository '$repo_name' does not exist."
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
        list_repo "$repo_name"
    else
        echo "Repository '$repo_name' does not exist."
    fi
}

function list_repo() {
    repo_name="$1"
    repo_path="$GLOBAL_DIR/$repo_name"

    # Check if the repository directory exists
    if [ -d "$repo_path" ]; then
        # List the content of the repository
        echo "Repository '$repo_name':"
        echo "Files:"
        ls "$repo_path"
    else
        echo "Repository '$repo_name' does not exist."
    fi
}

function list_logs() {
    # Check if the repository directory exists
    log_dir=$GLOBAL_DIR/$CURRENT_REPO/$GIP_DIR/logs
    log_count=0
    for log_file in "$log_dir"/*.log; do
        if [ -f "$log_file" ]; then
            log_count=$((log_count + 1))
            timestamp=$(basename "$timestamp" .log)

            echo "Log #$log_count - $timestamp"
            grep "^File: " "$log_file" | cut -d ' ' -f2 | echo "File: '$(cat)'"
            grep "^User: " "$log_file" | cut -d ' ' -f2 | echo "User: '$(cat)'"
            grep "^Content: " "$log_file" | cut -d ' ' -f2 | echo "Content: '$(cat)'"
            grep "^Comment: " "$log_file" | cut -d ' ' -f2 | echo "Comment: '$(cat)'"
            echo ""
        fi
    done

    if [ $log_count -eq 0 ]; then
        echo "No logs found in repository '$CURRENT_REPO'."
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
        read -p "Provide a comment: " comment
        log_file $file_name $content $comment
        echo "File '$file_name' created."
    fi
}

function remove_file() {
    file_name="$1"
    file_path="$GLOBAL_DIR/$CURRENT_REPO/$file_name"

    # Check if the file exists
    if [ -f "$file_path" ]; then
        rm "$file_path"
        read -p "Provide a comment: " comment
        log_file $file_name " " $comment
        echo "File '$file_name' removed."
    else
        echo "File '$file_name' does not exist."
    fi
}

function log_file() {
    timestamp=$(date +"%Y-%m-%d %T")
    log_file=$GLOBAL_DIR/$CURRENT_REPO/$GIP_DIR/logs/$timestamp.log
    echo "File: '$1'" >> "$log_file"
    echo "Timestamp: $timestamp" >> "$log_file"
    echo "User: '$USER'" >> "$log_file"
    echo "Content: '$2'" >> "$log_file"
    echo "Comment: '$3'" >> "$log_file"
}

function checkout_file() {
    lock_file="$GLOBAL_DIR/$CURRENT_REPO/$GIP_DIR/locks/$1.lock"

    if [ -e "$lock_file" ]; then
        echo "File '$1' is already being edited by another user."
    else
        # Create the lock file to indicate that the file is being edited
        touch "$lock_file"
        echo "User '$USER' has checked out '$1' for editing."
    fi
}

function checkin_file() {
    lock_file="$GLOBAL_DIR/$repo_name/$GIP_DIR/locks/$file_name.lock"
    if [ -e "$lock_file" ]; then
        # Remove the lock file to indicate that the file is no longer being edited
        rm "$lock_file"
        echo "User '$USER' has checked in '$1' after editing"
    else
        echo "File '$1' is not being edited by user '$2'"
    fi
}

function gip() {
    if [ "$1" = "init" ]; then
        init
    elif ! [ -d "$GLOBAL_DIR" ]; then
        echo "Main directory 'global' does not exist. Please run 'gip init' to create it"
    else 
        case "$1" in
            create)
                if [ $# -lt 2 ]; then
                    echo "Usage: gip create <repository_name>"
                else
                    create_repo "$2"
                fi
                ;;
            delete)
                if [ $# -lt 2 ]; then
                    echo "Usage: gip delete <repository_name>"
                else
                    delete_repo "$2"
                fi
                ;;
            switch)
                if [ $# -lt 2 ]; then
                    echo "Usage: gip switch <repository_name>"
                else
                    switch_repo "$2"
                fi
                ;;
            list)
                if [ $# -lt 2 ]; then
                    echo "Usage: gip list <repository_name>"
                else
                    list_repo "$2"
                fi
                ;;
            logs)
                if [ -z "$CURRENT_REPO" ]; then
                    echo "No repository created. Please run 'gip create <repository_name>' to create one"
                else
                    list_logs
                fi
                ;;
            add)
                if [ -z "$CURRENT_REPO" ]; then
                    echo "No repository created. Please run 'gip create <repository_name>' to create one"
                elif [ $# -lt 2 ]; then
                    echo "Usage: gip add <file_name>"
                elif [ ! -f "$2" ] && [ "$3" != "-e" ]; then
                    echo "File '$2' does not exist."
                else
                    content=" "
                    if [ "$3" != "-e" ]; then
                        content=$(cat "$2")
                    fi
                    add_file "$2" "$content"
                fi
                ;;
            remove)
                if [ -z "$CURRENT_REPO" ]; then
                    echo "No repository created. Please run 'gip create <repository_name>' to create one"
                elif [ $# -lt 2 ]; then
                    echo "Usage: gip remove <file_name>"
                else
                    remove_file "$2"
                fi
                ;;
            checkout)
                if [ -z "$CURRENT_REPO" ]; then
                    echo "No repository created. Please run 'gip create <repository_name>' to create one"
                elif [ $# -lt 2 ]; then
                    echo "Usage: gip checkout <file_name>"
                else
                    checkout_file "$2"
                fi
                ;;
            checkin)
                if [ -z "$CURRENT_REPO" ]; then
                    echo "No repository created. Please run 'gip create <repository_name>' to create one"
                elif [ $# -lt 2 ]; then
                    echo "Usage: gip checkin <file_name>"
                else
                    checkin_file "$2"
                fi
                ;;
            *)
                echo "Usage: gip <command>"
                echo "Commands:"
                echo "  init                Initialize the main directory for repositories"
                echo "  create <repo_name>  Create a new repository with the specified name"
            ;;
        esac
    fi
}

while true; do
    read -p ">>> " input
    if [ "$input" = "exit" ]; then
        break
    elif [[ "$input" =~ ^gip ]]; then
        IFS=" " read -a args <<< "$input"
        command="${args[1]}"
        gip $command "${args[@]:2}"
    else
        echo "Command not found"
    fi
done
