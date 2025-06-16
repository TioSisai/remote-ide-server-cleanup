#!/bin/bash

set -euo pipefail  # Strict mode: exit on error, undefined variables error, pipeline error handling

# --- Default Configuration ---
IDE_TYPE="vscode"
CLEAN_HISTORY=false
DRY_RUN=false
VERBOSE=false
# Provide a general default value for VS Code Server directory
VSCODE_SERVER_DEFAULT_DIR="$HOME/.vscode-server"
CURSOR_SERVER_DEFAULT_DIR="$HOME/.cursor-server" # Cursor's default directory

# --- Color and Style Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Helper Functions ---
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Safe deletion function
safe_remove() {
    local target="$1"
    local description="${2:-file/directory}"
    
    # Path safety check
    if [[ -z "$target" ]] || [[ "$target" == "/" ]] || [[ "$target" == "$HOME" ]]; then
        log_error "Refusing to delete dangerous path: $target"
        return 1
    fi
    
    # Ensure path is within expected server directory
    if [[ ! "$target" =~ ^"$SERVER_DIR" ]]; then
        log_error "Refusing to delete path outside server directory: $target"
        return 1
    fi
    
    if [[ ! -e "$target" ]]; then
        log_verbose "$description does not exist, skipping: $target"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Will delete $description: $(basename "$target")"
        return 0
    fi
    
    log_info "Deleting $description: $(basename "$target")"
    if rm -rf "$target" 2>/dev/null; then
        log_verbose "Successfully deleted: $target"
        return 0
    else
        log_error "Failed to delete: $target"
        return 1
    fi
}

# Check bash version and required commands
check_requirements() {
    # Check bash version (requires 4.0+)
    if (( BASH_VERSINFO[0] < 4 )); then
        log_error "Bash 4.0 or higher required (current: $BASH_VERSION)"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("find" "sort" "basename" "dirname")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Missing required command: $cmd"
            exit 1
        fi
    done
}

# Get file modification time (compatible with different systems)
get_mtime() {
    local file="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        stat -f "%m" "$file" 2>/dev/null || echo "0"
    else
        # Linux
        stat -c "%Y" "$file" 2>/dev/null || echo "0"
    fi
}

# Version comparison function (replacement for sort -V)
version_compare() {
    local ver1="$1"
    local ver2="$2"
    
    # Extract version numbers
    ver1=$(echo "$ver1" | sed -E 's/.*-([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    ver2=$(echo "$ver2" | sed -E 's/.*-([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    
    # Simple version comparison
    if [[ "$ver1" == "$ver2" ]]; then
        return 0
    fi
    
    local IFS=.
    local ver1_array=($ver1)
    local ver2_array=($ver2)
    
    for ((i=0; i<3; i++)); do
        local v1=${ver1_array[i]:-0}
        local v2=${ver2_array[i]:-0}
        
        if (( v1 < v2 )); then
            return 1
        elif (( v1 > v2 )); then
            return 0
        fi
    done
    
    return 0
}

# --- Parameter Parsing ---
show_help() {
    cat << EOF
Usage: $0 [options]
  
Clean up old files and caches related to IDE Server

Options:
    -V, --vscode    Clean VS Code Server related content (default)
    -C, --cursor    Clean Cursor IDE Server related content
    -H, --history   Clean User/History directory (Warning: will delete file history)
    -d, --dry-run   Preview mode, only show what will be deleted without actually deleting
    -v, --verbose   Verbose output mode
    -h, --help      Show this help message

Environment Variables:
    MY_VSCODE_SERVER_DIR    Custom VS Code Server directory path
    MY_CURSOR_SERVER_DIR    Custom Cursor Server directory path

Examples:
    $0 --dry-run                # Preview what will be cleaned
    $0 --cursor --history       # Clean Cursor including history
    $0 --vscode --verbose       # Clean VS Code with verbose output
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -V|--vscode)
            IDE_TYPE="vscode"
            shift
            ;;
        -C|--cursor)
            IDE_TYPE="cursor"
            shift
            ;;
        -H|--history)
            CLEAN_HISTORY=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use '$0 --help' for help."
            exit 1
            ;;
    esac
done

# --- Environment Check ---
check_requirements

# --- Environment Setup and Check ---
# Set server directory based on selected IDE type
if [[ "$IDE_TYPE" == "cursor" ]]; then
    # Use environment variable first, otherwise use default
    SERVER_DIR="${MY_CURSOR_SERVER_DIR:-$CURSOR_SERVER_DEFAULT_DIR}"
    log_info "Target IDE: Cursor"
elif [[ "$IDE_TYPE" == "vscode" ]]; then
    # Use environment variable first, otherwise use default
    SERVER_DIR="${MY_VSCODE_SERVER_DIR:-$VSCODE_SERVER_DEFAULT_DIR}"
    log_info "Target IDE: VS Code"
fi

log_info "Using server main directory: $SERVER_DIR"

# Absolute path conversion and validation
SERVER_DIR=$(readlink -f "$SERVER_DIR" 2>/dev/null || echo "$SERVER_DIR")

# Check if main directory exists
if [[ ! -d "$SERVER_DIR" ]]; then
    log_error "Main directory not found: $SERVER_DIR"
    log_error "Please confirm if IDE Server is installed, or specify correct path via environment variable MY_VSCODE_SERVER_DIR/MY_CURSOR_SERVER_DIR."
    exit 1
fi

# Safety check: ensure it's not a system critical directory
case "$SERVER_DIR" in
    /|/bin|/sbin|/usr|/etc|/var|/home|/root)
        log_error "Refusing to operate on system critical directory: $SERVER_DIR"
        exit 1
        ;;
esac

if [[ "$DRY_RUN" == true ]]; then
    log_warning "Running in preview mode, no files will actually be deleted"
fi

echo "=================================================="

# ==============================================================================
# Cleanup Logic
# ==============================================================================

# --- Step 1: Clean up old Server versions ---
log_info "Step 1: Cleaning up old Server versions..."

# Check new 'bin' directory, if it doesn't exist, fallback to check old 'cli/servers' directory
CLI_SERVERS_DIR="$SERVER_DIR/bin"
if [[ ! -d "$CLI_SERVERS_DIR" ]]; then
    log_verbose "Service directory not found in $SERVER_DIR/bin, checking old path..."
    CLI_SERVERS_DIR_OLD="$SERVER_DIR/cli/servers"
    if [[ -d "$CLI_SERVERS_DIR_OLD" ]]; then
        CLI_SERVERS_DIR="$CLI_SERVERS_DIR_OLD"
        log_verbose "Found and using old service directory: $CLI_SERVERS_DIR"
    else
        log_info "Step 1: Server Binaries directory not found (neither in bin/ nor cli/servers/), skipping."
        CLI_SERVERS_DIR=""
    fi
fi

# check if the directory name is a valid commit hash
is_valid_commit_hash() {
    local dir_name="$1"
    
    # exclude known special directory names
    case "$dir_name" in
        "multiplex-server"|"cli"|"stable"|"insiders"|"latest")
            return 1
            ;;
    esac
    
    # Git commit hash is usually 40 hex digits, but allows some variation:
    # - Standard 40 hex digits string (most common)
    # - Short SHA-1 hash (at least 7 digits, used for short version identifier)
    # - May contain version suffix format (e.g. hash-version)
    if [[ "$dir_name" =~ ^[a-f0-9]{7,40}$ ]]; then
        return 0
    fi
    
    # Check if it's a hash format with version suffix (e.g. hash-version)
    if [[ "$dir_name" =~ ^[a-f0-9]{7,40}-[0-9a-zA-Z._-]+$ ]]; then
        return 0
    fi
    
    return 1
}

# Only continue if CLI_SERVERS_DIR actually exists
if [[ -n "$CLI_SERVERS_DIR" ]]; then
    # Find all Server directories and sort by modification time
    declare -a server_dirs=()
    declare -A server_times=()
    
    while IFS= read -r -d '' dir; do
        if [[ -d "$dir" ]]; then
            dir_name=$(basename "$dir")
            # only process directories that are valid commit hashes
            if is_valid_commit_hash "$dir_name"; then
                mtime=$(get_mtime "$dir")
                server_dirs+=("$dir")
                server_times["$dir"]="$mtime"
                log_verbose "Found valid server version: $dir_name"
            else
                log_verbose "Skipping non-version directory: $dir_name (not a valid commit hash)"
            fi
        fi
    done < <(find "$CLI_SERVERS_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
    
    if [[ ${#server_dirs[@]} -eq 0 ]]; then
        log_info "No Server versions found in $CLI_SERVERS_DIR."
    elif [[ ${#server_dirs[@]} -eq 1 ]]; then
        log_info "Only one Server version exists, no cleanup needed."
    else
        # Sort by modification time (newest first)
        IFS=$'\n' sorted_dirs=($(
            for dir in "${server_dirs[@]}"; do
                echo "${server_times[$dir]}:$dir"
            done | sort -nr | cut -d: -f2-
        ))
        
        if [[ ${#sorted_dirs[@]} -gt 0 ]]; then
            LATEST_SERVER_DIR="${sorted_dirs[0]}"
            LATEST_COMMIT_HASH=$(basename "$LATEST_SERVER_DIR")
            log_info "Detected latest version Hash: $LATEST_COMMIT_HASH"
            log_info "Keeping latest Server package: $LATEST_COMMIT_HASH"
            
            # Iterate and delete old versions
            for ((i=1; i<${#sorted_dirs[@]}; i++)); do
                old_server_dir="${sorted_dirs[$i]}"
                old_commit_hash=$(basename "$old_server_dir")
                
                log_info "Preparing to delete old version: $old_commit_hash"
                
                # 1. Delete old Server package in bin or cli/servers directory
                safe_remove "$old_server_dir" "old Server package"
                
                # 2. Clean up associated files in root directory based on IDE type
                if [[ "$IDE_TYPE" == "cursor" ]]; then
                    # For Cursor, clean .log, .pid, .token files (starting with "." + hash)
                    while IFS= read -r -d '' old_file; do
                        safe_remove "$old_file" "old associated file"
                    done < <(find "$SERVER_DIR" -maxdepth 1 -type f -name ".${old_commit_hash}*" -print0 2>/dev/null)
                elif [[ "$IDE_TYPE" == "vscode" ]]; then
                    # For VSCode, clean code-* launchers and .cli.*.log logs
                    while IFS= read -r -d '' old_file; do
                        safe_remove "$old_file" "old associated file"
                    done < <(find "$SERVER_DIR" -maxdepth 1 -type f \( -name "code-${old_commit_hash}" -o -name ".cli.${old_commit_hash}.log" \) -print0 2>/dev/null)
                fi
            done
        fi
    fi
    
    # Only show completion message when not in dry-run mode
    if [[ "$DRY_RUN" != true ]]; then
        log_success "Step 1: Server version cleanup completed!"
    fi
fi
echo "--------------------------------------------------"

# --- Step 2: Clean up old extension versions (extensions) ---
EXTENSIONS_DIR="$SERVER_DIR/extensions"
if [[ -d "$EXTENSIONS_DIR" ]]; then
    log_info "Step 2: Cleaning up old extension versions..."
    
    # Collect all extensions and their versions
    declare -A extension_versions=()
    
    while IFS= read -r -d '' ext_dir; do
        if [[ -d "$ext_dir" ]]; then
            ext_name=$(basename "$ext_dir")
            # Improved version extraction regex
            if [[ "$ext_name" =~ ^(.+)-([0-9]+\.[0-9]+\.[0-9]+.*)$ ]]; then
                base_name="${BASH_REMATCH[1]}"
                version="${BASH_REMATCH[2]}"
                
                if [[ -z "${extension_versions[$base_name]:-}" ]]; then
                    extension_versions[$base_name]="$ext_dir"
                else
                    extension_versions[$base_name]="${extension_versions[$base_name]}|$ext_dir"
                fi
            fi
        fi
    done < <(find "$EXTENSIONS_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
    
    # Process multiple versions of each extension
    found_duplicates=false
    for base_name in "${!extension_versions[@]}"; do
        IFS='|' read -ra versions <<< "${extension_versions[$base_name]}"
        
        if [[ ${#versions[@]} -gt 1 ]]; then
            found_duplicates=true
            log_info "Found multiple versions of \"$base_name\"..."
            
            # Sort by modification time, keep the newest
            declare -a version_times=()
            for version_dir in "${versions[@]}"; do
                mtime=$(get_mtime "$version_dir")
                version_times+=("$mtime:$version_dir")
            done
            
            IFS=$'\n' sorted_versions=($(printf '%s\n' "${version_times[@]}" | sort -nr | cut -d: -f2-))
            
            latest_version="${sorted_versions[0]}"
            log_info "Keeping latest: $(basename "$latest_version")"
            
            # Delete all old versions except the latest
            for ((i=1; i<${#sorted_versions[@]}; i++)); do
                old_version="${sorted_versions[$i]}"
                safe_remove "$old_version" "old extension version"
            done
        else
            log_verbose "\"$base_name\" has only one version, no cleanup needed."
        fi
    done
    
    if [[ "$found_duplicates" == false ]]; then
        log_info "No duplicate extension versions need cleanup."
    fi
    
    # Only show completion message when not in dry-run mode
    if [[ "$DRY_RUN" != true ]]; then
        log_success "Step 2: Extensions directory cleanup completed!"
    fi
else
    log_info "Step 2: Extensions directory not found ($EXTENSIONS_DIR), skipping."
fi
echo "--------------------------------------------------"

# --- Step 3 & 4: Clean up data directory ---
DATA_DIR="$SERVER_DIR/data"

log_info "Step 3: Scanning data directory: $DATA_DIR"

if [[ ! -d "$DATA_DIR" ]]; then
    log_info "Step 3: data directory not found, skipping."
else
    # Clean up caches and logs
    cache_dirs=("logs" "CachedExtensionVSIXs" "clp")
    found_cache=false
    for cache_dir in "${cache_dirs[@]}"; do
        cache_path="$DATA_DIR/$cache_dir"
        if [[ -d "$cache_path" ]]; then
            found_cache=true
            safe_remove "$cache_path" "cache directory $cache_dir"
        fi
    done
    
    if [[ "$found_cache" == false ]]; then
        log_info "No cache directories need cleanup."
    fi
    
    # Only show completion message when not in dry-run mode
    if [[ "$DRY_RUN" != true ]]; then
        log_success "Step 3: data cache cleanup completed!"
    fi
    echo "--------------------------------------------------"
    
         # Clean history if requested
     if [[ "$CLEAN_HISTORY" == true ]]; then
         HISTORY_DIR="$DATA_DIR/User/History"
         if [[ -d "$HISTORY_DIR" ]]; then
             log_warning "Step 4: Cleaning history directory: $HISTORY_DIR"
             safe_remove "$HISTORY_DIR" "history directory"
             # Only show completion message when not in dry-run mode
             if [[ "$DRY_RUN" != true ]]; then
                 log_success "Step 4: History directory cleanup completed!"
             fi
         else
             log_info "Step 4: History directory not found ($HISTORY_DIR), skipping."
         fi
     fi
fi

echo "--------------------------------------------------"
if [[ "$DRY_RUN" == true ]]; then
    log_info "Preview mode completed! Above shows what will be cleaned (remove --dry-run parameter to actually execute)"
else
    log_success "All cleanup steps completed!"
fi 
