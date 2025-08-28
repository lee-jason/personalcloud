# Personal Cloud Storage

Simple S3 Glacier Deep Archive backup solution with Terraform and Make.

## Quick Start

1. **Deploy infrastructure:**
   ```bash
   make setup
   ```

2. **Configure AWS credentials:**
   ```bash
   make credentials
   ```

3. **Upload files:**
   ```bash
   mkdir backup
   cp -r ~/Documents/important-stuff backup/
   make push
   ```

## Commands

- `make help` - Show all commands
- `make setup` - Deploy S3 bucket and IAM user
- `make push` - Upload files to Glacier Deep Archive
- `make restore` - Start file restoration (12-48 hours)
- `make pull` - Download restored files
- `make status` - Check restoration progress
- `make info` - Show bucket details
- `make clean` - Destroy everything

## How It Works

- **Push**: Files go directly to Glacier Deep Archive (~$1/TB/month)
- **Pull**: Requires restoration first (costs ~$0.02/GB + temp storage)
- **Storage**: Minimum 180 days, early deletion fees apply

Files are stored in `./backup/` locally and synced to S3.