# VCS - Version Control System

A Git-like version control system implemented in Swift with pluggable compression strategies.

## Features

- SHA-256 content addressing
- Pluggable compression (zlib, LZ4, or none)
- File type-based compression selection
- Per-file compression overrides
- Tree and commit objects
- Checkout functionality
- Repository initialization and history

## Architecture

### Compression System

The compression system is designed to be flexible and extensible:

- **CompressionStrategy Protocol**: Defines the interface for compression implementations
- **CompressionRegistry**: Manages compression strategies and routing based on file types/paths
- **Built-in Strategies**:
  - `zlib`: General-purpose compression for text files
  - `lz4`: Fast compression for logs and temporary files
  - `none`: No compression for already-compressed files (images, videos, archives)

### Object Storage

Uses a content-addressable file store with:
- **Blob**: File content with compression metadata
- **Tree**: Directory structure mapping names to hashes
- **Commit**: Snapshot with tree reference, parent, author, and message

### Default Compression Rules

- **No compression**: jpg, jpeg, png, gif, zip, gz, bz2, mp4, mp3, pdf
- **Zlib compression**: txt, md, swift, rs, js, ts, json, xml, html, css
- **LZ4 compression**: log files

## Usage

```bash
# Initialize a repository
vcs init

# Create a commit
vcs commit "Initial commit"

# View history
vcs log

# Checkout a commit
vcs checkout <hash>

# Configure compression by extension
vcs compression set txt lz4

# Override compression for specific file
vcs compression override config.json none
```

## Implementation Details

- Uses SHA-256 for hashing (more secure than Git's SHA-1)
- Stores objects in `.vcs/objects` with 2-char prefix sharding
- JSON encoding for tree and commit objects
- Custom format for blob objects including compression metadata
- Ignore patterns via `.vcsignore` file
