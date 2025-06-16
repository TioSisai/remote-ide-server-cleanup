# IDE Server Cleanup Script

A simple and flexible Bash script to clean up old and unnecessary files from your VS Code Server or Cursor Server installations, helping you reclaim disk space and maintain a tidy environment.

## About The Project

When using VS Code or Cursor in a remote server environment, the server-side components can accumulate a significant amount of data over time. This includes multiple versions of the server binaries, outdated extensions, caches, and logs. This script provides an automated and safe way to clean up this data, keeping only the most recent versions and essential files.

This script is designed to be:

  * **Safe**: It includes multiple safety checks to prevent accidental deletion of important system directories. It also offers a `--dry-run` mode to preview changes.
  * **Flexible**: It supports both **VS Code Server** and **Cursor Server**.
  * **Smart**: It intelligently finds and removes outdated server binaries and duplicate extension versions, keeping only the latest ones.
  * **Thorough**: It cleans up various cache directories and can optionally clear file history.

## Features

  - **Multi-IDE Support**: Clean up `VS Code Server` (`.vscode-server`) or `Cursor Server` (`.cursor-server`).
  - **Old Server Version Cleanup**: Detects all installed server binary versions, keeps the most recent one, and removes all others along with their associated log files.
  - **Old Extension Cleanup**: Scans the `extensions` directory, identifies extensions with multiple installed versions, and removes all but the most recently modified version.
  - **Cache Cleaning**: Deletes common cache and log directories within the `data` folder, such as `logs`, `CachedExtensionVSIXs`, and `clp`.
  - **Optional History Cleaning**: Includes an option to clear the `User/History` directory, which contains local file history. Use with caution.
  - **Dry Run Mode**: Preview exactly which files and directories will be deleted without making any actual changes.
  - **Custom Directory Support**: Specify a custom path for the server directory using environment variables.
  - **Verbose Output**: Get detailed information about the script's operations.
  - **Safety First**: Implements strict checks to avoid operating on critical system paths (`/`, `$HOME`, `/usr`, etc.).

## Prerequisites

Before running the script, ensure your system meets the following requirements:

  - **Bash Version**: `Bash 4.0` or higher.
  - **Required Commands**: `find`, `sort`, `basename`, `dirname`, `stat`, `readlink`. These are standard on most Linux and macOS systems.

## Installation

1.  Save the script to a file named `cleanup_ide_server.sh`.
2.  Make the script executable:
    ```bash
    chmod +x cleanup_ide_server.sh
    ```
3.  (Optional) Move the script to a directory in your `PATH` for easy access from anywhere, for example:
    ```bash
    sudo mv cleanup_ide_server.sh /usr/local/bin/cleanup-ide
    ```

## Usage

You can run the script with various options to control its behavior.

```bash
./cleanup_ide_server.sh [options]
```

### Options

| Short Flag | Long Flag     | Description                                                          |
| :--------- | :------------ | :------------------------------------------------------------------- |
| `-V`       | `--vscode`    | Clean VS Code Server related content (This is the default).          |
| `-C`       | `--cursor`    | Clean Cursor IDE Server related content.                             |
| `-H`       | `--history`   | Clean the `User/History` directory. **Warning**: This deletes file history. |
| `-d`       | `--dry-run`   | Preview mode. Shows what would be deleted without actually deleting. |
| `-v`       | `--verbose`   | Enable verbose output for detailed logging.                          |

  - `-h`
  - `--help`
  - Show the help message.

### Environment Variables

You can override the default server directories by setting these environment variables:

  - `MY_VSCODE_SERVER_DIR`: Set a custom path for the VS Code Server directory.
  - `MY_CURSOR_SERVER_DIR`: Set a custom path for the Cursor Server directory.

For example:

```bash
export MY_VSCODE_SERVER_DIR="/path/to/your/.vscode-server"
./cleanup_ide_server.sh
```

## Examples

1.  **Preview the cleanup for VS Code Server (default)**:
    *A safe way to see what the script will do.*

    ```bash
    ./cleanup_ide_server.sh --dry-run
    ```

2.  **Perform a full cleanup on Cursor Server, including history**:
    *This will clean old server versions, extensions, caches, and the file history for Cursor.*

    ```bash
    ./cleanup_ide_server.sh --cursor --history
    ```

3.  **Clean VS Code Server with detailed output**:
    *Useful for debugging or understanding the script's actions.*

    ```bash
    ./cleanup_ide_server.sh --vscode --verbose
    ```

4.  **Clean a VS Code Server located in a custom directory**:

    ```bash
    MY_VSCODE_SERVER_DIR="/opt/vscode-server-data" ./cleanup_ide_server.sh
    ```

## How It Works

The script performs the cleanup in a series of logical steps:

1.  **Initialization**:

      * It starts in "strict mode" (`set -euo pipefail`) to prevent errors from going unnoticed.
      * It parses command-line arguments to set the configuration (IDE type, dry-run, etc.).
      * It determines the target server directory (`~/.vscode-server` or `~/.cursor-server` by default, or a custom path).
      * It performs essential environment and safety checks.

2.  **Step 1: Clean Old Server Versions**:

      * The script looks for server binaries, typically located in the `bin/` directory.
      * It identifies all installed versions and sorts them by modification time to find the latest one.
      * It deletes all server directories except for the latest one.
      * It also removes associated files (like logs and launchers) that correspond to the old versions.

3.  **Step 2: Clean Old Extension Versions**:

      * The script scans the `$SERVER_DIR/extensions` directory.
      * It groups installed extensions by their base name (e.g., `ms-python.python`).
      * If an extension has multiple version folders, it keeps the one with the most recent modification time and deletes the others.

4.  **Step 3 & 4: Clean Data and History**:

      * The script cleans common cache directories within `$SERVER_DIR/data`, such as `logs` and `CachedExtensionVSIXs`.
      * If the `--history` flag is used, it will also remove the `$SERVER_DIR/data/User/History` directory.

## Contributing

Contributions are welcome\! If you have suggestions for improvements or find a bug, please feel free to open an issue or submit a pull request on the project's repository.

## Disclaimer

This script is provided "as is" and without any warranty. The author assumes no liability for any potential data loss or damage resulting from its use. You are solely responsible for any consequences of running this script.

**It is strongly recommended to:**

1.  **Back up any important data** before running the script.
2.  Use the `--dry-run` option first to review the files and directories that will be deleted.

## License

This script is released under the MIT License. See the `LICENSE` file for more details.
