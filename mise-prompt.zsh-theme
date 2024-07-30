#!/bin/zsh

# Load Version Control Information
autoload -Uz vcs_info

# Load colors function
autoload -U colors && colors

# Enable style options for git via the vcs_info plugin 
zstyle ':vcs_info:*' enable git 

# Function to display vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )

setopt prompt_subst

# Enable displaying untracked files and staged changes
zstyle ':vcs_info:git*+set-message:*' hooks git-untracked git-staged

# Display a plus sign if there are staged changes
+vi-git-staged() {
    if [[ $(git diff --cached --name-only 2> /dev/null) != "" ]]; then
        hook_com[staged]+="+"
    fi
}

# Display a bang if there are untracked files
+vi-git-untracked() {
    if [[ $(git ls-files --others --exclude-standard 2> /dev/null) != "" ]]; then
        hook_com[unstaged]+="!"
    fi
}

# Use hooks to check for changes in git
zstyle ':vcs_info:*' check-for-changes true

# Format git information (without brackets)
zstyle ':vcs_info:git:*' formats " %F{3}%b%F{1}%u%F{2}%c%f"
zstyle ':vcs_info:git:*' actionformats " %F{3}%b%F{1}%u%F{2}%c%f %F{5}(%a)%f"

# Function to check for mise config files
function check_mise_config() {
    local config_files=(
        ".mise.local.toml"
        "mise.local.toml"
        ".mise.$MISE_ENV.toml"
        "mise.$MISE_ENV.toml"
        ".mise.toml"
        ".mise/config.toml"
        "mise.toml"
        "mise/config.toml"
        ".config/mise.toml"
        ".config/mise/config.toml"
    )

    local dir=$PWD
    while [[ "$dir" != "/" ]]; do
        for file in "${config_files[@]}"; do
            if [[ -f "$dir/$file" ]]; then
                return 0
            fi
        done
        dir=${dir:h}
    done

    return 1
}

# Function to get mise runtime versions with icons
function get_mise_versions() {
    # Check if any mise config file exists
    if ! check_mise_config; then
        return
    fi

    local versions=""
    local separator=" %F{8}·%f "  # Light gray dot separator

    if command -v mise &> /dev/null; then
        # Get mise output
        local mise_output=$(mise current 2>/dev/null)
        
        # Python
        local python_version=$(echo "$mise_output" | awk '$1 == "python" {print $2}')
        if [[ -n "$python_version" ]]; then
            versions+="%F{2}󰌠 $python_version%f"
        fi
        
        # Node.js
        local node_version=$(echo "$mise_output" | awk '$1 == "node" {print $2}')
        if [[ -n "$node_version" ]]; then
            [[ -n "$versions" ]] && versions+="$separator"
            versions+="%F{2}󰎙 $node_version%f"
        fi
        
        # npm (we'll use node to get npm version)
        if [[ -n "$node_version" ]]; then
            local npm_version=$(npm --version 2>/dev/null)
            if [[ -n "$npm_version" ]]; then
                [[ -n "$versions" ]] && versions+="$separator"
                versions+="%F{2}󰛷 $npm_version%f"
            fi
        fi
        
        # Rust
        local rust_version=$(echo "$mise_output" | awk '$1 == "rust" {print $2}')
        if [[ -n "$rust_version" ]]; then
            [[ -n "$versions" ]] && versions+="$separator"
            versions+="%F{2} $rust_version%f"
        fi
        
        # Ruby
        local ruby_version=$(echo "$mise_output" | awk '$1 == "ruby" {print $2}')
        if [[ -n "$ruby_version" ]]; then
            [[ -n "$versions" ]] && versions+="$separator"
            versions+="%F{2}󰛥 $ruby_version%f"
        fi
    fi

    if [[ -n "$versions" ]]; then
        echo "$versions"
    fi
}

# Function to get git ahead/behind information
function git_ahead_behind() {
    local ahead behind
    ahead=$(git rev-parse --verify @{upstream} >/dev/null 2>&1 && git rev-list --count @{upstream}..HEAD 2>/dev/null)
    behind=$(git rev-parse --verify @{upstream} >/dev/null 2>&1 && git rev-list --count HEAD..@{upstream} 2>/dev/null)

    if [[ $ahead -gt 0 ]] || [[ $behind -gt 0 ]]; then
        echo " %F{3}[%F{2}+$ahead%F{3}|%F{1}-$behind%F{3}]%f"
    fi
}

# Set the prompt
PROMPT='%F{4}%~%f${vcs_info_msg_0_}$(git_ahead_behind)%F{8} · %f$(get_mise_versions)
%F{5}$%f '

# Update vcs_info before each prompt
precmd() {
    vcs_info
}