#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values from JSON
model_name=$(echo "$input" | jq -r '.model.display_name')
model_id=$(echo "$input" | jq -r '.model.id')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
version=$(echo "$input" | jq -r '.version')
transcript_path=$(echo "$input" | jq -r '.transcript_path')

# Extract cost information
session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // "0"')
total_duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // "0"')
api_duration_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // "0"')

# Read token usage from transcript file
# Get the LAST message's usage for current context size
# Sum all output tokens for total output
total_input=0
total_output=0
current_context=0

if [ -f "$transcript_path" ]; then
    # Get the last usage entry for current context (most recent state)
    last_usage=$(tail -20 "$transcript_path" | jq -s '[.[] | select(.message.usage != null)] | last | .message.usage' 2>/dev/null)

    if [ -n "$last_usage" ] && [ "$last_usage" != "null" ]; then
        # Current context = input_tokens + cache_read (what's currently in the context window)
        last_input=$(echo "$last_usage" | jq -r '.input_tokens // 0')
        last_cache_read=$(echo "$last_usage" | jq -r '.cache_read_input_tokens // 0')
        last_cache_creation=$(echo "$last_usage" | jq -r '.cache_creation_input_tokens // 0')
        current_context=$((last_input + last_cache_read + last_cache_creation))
    fi

    # Sum all tokens for totals
    token_sums=$(jq -s '
        [.[] | select(.message.usage != null) | .message.usage] |
        {
            input: (map(.input_tokens // 0) | add),
            output: (map(.output_tokens // 0) | add)
        }
    ' "$transcript_path" 2>/dev/null)

    if [ -n "$token_sums" ]; then
        total_input=$(echo "$token_sums" | jq -r '.input // 0')
        total_output=$(echo "$token_sums" | jq -r '.output // 0')
    fi
fi

# Determine context window size based on model
context_window_size=200000
model_lower=$(echo "$model_id" | tr '[:upper:]' '[:lower:]')
if [[ "$model_lower" == *"sonnet"* ]]; then
    # Sonnet models can have 1M context
    context_window_size=1000000
fi

# Get model icon based on model name (case insensitive)
model_icon=""
name_lower=$(echo "$model_name" | tr '[:upper:]' '[:lower:]')
case "$name_lower" in
    *opus*) model_icon="🎭" ;;
    *sonnet*) model_icon="🎵" ;;
    *haiku*) model_icon="🌸" ;;
    *) model_icon="🤖" ;;
esac

# Convert current_dir to tilde notation if it starts with home directory
home_dir="$HOME"
if [[ "$current_dir" == "$home_dir"* ]]; then
    dir_display="~${current_dir#$home_dir}"
else
    dir_display="$current_dir"
fi

# Get git status if in a git repository
git_info=""
if [ -d "$current_dir/.git" ] || git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$current_dir" branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        # Get combined statistics for staged, unstaged, and untracked files
        insertions=0
        deletions=0

        # Get unstaged changes
        unstaged_diff=$(git -C "$current_dir" diff --shortstat 2>/dev/null)
        if [ -n "$unstaged_diff" ]; then
            unstaged_ins=$(echo "$unstaged_diff" | grep -o '[0-9]\+ insertion' | cut -d' ' -f1 2>/dev/null || echo "0")
            unstaged_del=$(echo "$unstaged_diff" | grep -o '[0-9]\+ deletion' | cut -d' ' -f1 2>/dev/null || echo "0")
            [ -n "$unstaged_ins" ] && insertions=$((insertions + unstaged_ins))
            [ -n "$unstaged_del" ] && deletions=$((deletions + unstaged_del))
        fi

        # Get staged changes
        staged_diff=$(git -C "$current_dir" diff --cached --shortstat 2>/dev/null)
        if [ -n "$staged_diff" ]; then
            staged_ins=$(echo "$staged_diff" | grep -o '[0-9]\+ insertion' | cut -d' ' -f1 2>/dev/null || echo "0")
            staged_del=$(echo "$staged_diff" | grep -o '[0-9]\+ deletion' | cut -d' ' -f1 2>/dev/null || echo "0")
            [ -n "$staged_ins" ] && insertions=$((insertions + staged_ins))
            [ -n "$staged_del" ] && deletions=$((deletions + staged_del))
        fi

        # Count lines in untracked files
        untracked_files=$(git -C "$current_dir" ls-files --others --exclude-standard 2>/dev/null)
        if [ -n "$untracked_files" ]; then
            while IFS= read -r file; do
                if [ -f "$current_dir/$file" ]; then
                    lines=$(wc -l < "$current_dir/$file" 2>/dev/null || echo "0")
                    insertions=$((insertions + lines))
                fi
            done <<< "$untracked_files"
        fi

        # Only show diff stats if there are changes
        if [ "$insertions" -gt 0 ] || [ "$deletions" -gt 0 ]; then
            git_info=" ${branch} (+${insertions},-${deletions})"
        else
            git_info=" ${branch}"
        fi
    fi
fi

# Define color codes
CYAN='\033[36m'
YELLOW='\033[33m'
GREEN='\033[32m'
RED='\033[31m'
MAGENTA='\033[35m'
BLUE='\033[34m'
DIM_GRAY='\033[2;37m'
ORANGE='\033[38;5;208m'
PURPLE='\033[38;5;141m'
LIGHT_BLUE='\033[38;5;117m'
WHITE='\033[37m'
RESET='\033[0m'

# Helper function to format tokens to K format
format_tokens() {
    local tokens=$1
    if [[ "$tokens" =~ ^[0-9]+$ ]] && [ "$tokens" -ge 1000000 ]; then
        local tokens_m=$(echo "scale=1; $tokens / 1000000" | bc 2>/dev/null || echo "$tokens")
        if [[ "$tokens_m" =~ \.0$ ]]; then
            tokens_m=${tokens_m%.0}
        fi
        echo "${tokens_m}M"
    elif [[ "$tokens" =~ ^[0-9]+$ ]] && [ "$tokens" -ge 1000 ]; then
        local tokens_k=$(echo "scale=1; $tokens / 1000" | bc 2>/dev/null || echo "$tokens")
        if [[ "$tokens_k" =~ \.0$ ]]; then
            tokens_k=${tokens_k%.0}
        fi
        echo "${tokens_k}K"
    else
        echo "$tokens"
    fi
}

# Helper function to format duration (ms to human readable)
format_duration() {
    local ms=$1
    if [[ ! "$ms" =~ ^[0-9]+$ ]] || [ "$ms" -eq 0 ]; then
        echo ""
        return
    fi
    local seconds=$((ms / 1000))
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))

    if [ "$minutes" -gt 0 ]; then
        echo "${minutes}m${remaining_seconds}s"
    else
        echo "${seconds}s"
    fi
}

# Format session cost
cost_display=""
if [[ "$session_cost" != "0" && "$session_cost" != "null" ]]; then
    if [[ "$session_cost" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        formatted_cost=$(printf "%.4f" "$session_cost")
        cost_display="\$${formatted_cost}"
    else
        cost_display="\$${session_cost}"
    fi
fi

# Format duration display
duration_display=""
total_dur=$(format_duration "$total_duration_ms")
api_dur=$(format_duration "$api_duration_ms")
if [ -n "$total_dur" ] && [ -n "$api_dur" ]; then
    duration_display="${PURPLE}⏱️ ${total_dur} (${api_dur} API)${RESET}"
fi

# Format token display
tokens_display=""
if [ "$current_context" -gt 0 ] || [ "$total_output" -gt 0 ]; then
    # Calculate percentage of full context window
    context_percentage=$((current_context * 100 / context_window_size))

    # Format values
    input_display=$(format_tokens "$total_input")
    output_display=$(format_tokens "$total_output")
    context_display=$(format_tokens "$current_context")
    window_display=$(format_tokens "$context_window_size")

    # Color the percentage and add icon based on usage level
    # 🧠 = clever (low usage), 🤖 = normal, 🥴 = degraded (high usage)
    if [ "$context_percentage" -lt 40 ]; then
        percentage_colored="🧠 ${GREEN}${context_percentage}%${RESET}"
    elif [ "$context_percentage" -lt 70 ]; then
        percentage_colored="🤖 ${YELLOW}${context_percentage}%${RESET}"
    else
        percentage_colored="🥴 ${RED}${context_percentage}%${RESET}"
    fi

    # Build tokens display with different colors:
    # LIGHT_BLUE for ↓input ↑output, WHITE for context/window, colored percentage
    tokens_display="${LIGHT_BLUE}↓${input_display} ↑${output_display}${RESET} ${DIM_GRAY}|${RESET} ${WHITE}${context_display}/${window_display}${RESET} (${percentage_colored})"
fi

# Build session info display
session_info=""
info_parts=()

if [[ -n "$duration_display" ]]; then
    info_parts+=("$(echo -e "${duration_display}")")
fi

if [[ -n "$cost_display" ]]; then
    info_parts+=("$(echo -e "${ORANGE}${cost_display}${RESET}")")
fi

if [[ -n "$tokens_display" ]]; then
    info_parts+=("$(echo -e "${tokens_display}")")
fi

# Join all parts with separators
if [ ${#info_parts[@]} -gt 0 ]; then
    session_info=" $(echo -e "${DIM_GRAY}|${RESET}")"
    for i in "${!info_parts[@]}"; do
        session_info+=" ${info_parts[$i]}"
        if [ $i -lt $((${#info_parts[@]} - 1)) ]; then
            session_info+=" $(echo -e "${DIM_GRAY}|${RESET}")"
        fi
    done
fi

# Create the status line with colors
if [ -n "$git_info" ]; then
    # Parse git info to colorize diff stats separately
    if [[ "$git_info" =~ ^\ ([^\ ]+)\ \(\+([0-9]+),-([0-9]+)\)$ ]]; then
        branch_name="${BASH_REMATCH[1]}"
        insertions="${BASH_REMATCH[2]}"
        deletions="${BASH_REMATCH[3]}"
        git_colored=" $(echo -e "${YELLOW}${branch_name}${RESET}") ($(echo -e "${GREEN}+${insertions}${RESET}"),$(echo -e "${RED}-${deletions}${RESET}"))"
    else
        # Just branch name, no diff stats
        branch_name=$(echo "$git_info" | sed 's/^ //')
        git_colored=" $(echo -e "${YELLOW}${branch_name}${RESET}")"
    fi
    echo -e "$(echo -e "${CYAN}${dir_display}${RESET}") $(echo -e "${DIM_GRAY}|${RESET}")${git_colored} $(echo -e "${DIM_GRAY}|${RESET}") $(echo -e "${MAGENTA}${model_icon} ${model_name}${RESET}")${session_info}"
else
    echo -e "$(echo -e "${CYAN}${dir_display}${RESET}") $(echo -e "${DIM_GRAY}|${RESET}") $(echo -e "${MAGENTA}${model_icon} ${model_name}${RESET}")${session_info}"
fi
