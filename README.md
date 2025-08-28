# Personal Cloud Storage

Simple S3 Glacier Deep Archive backup solution with Terraform and Make.

## Quick Start

1. **Bootstrap Terraform state (run once):**
   ```bash
   make bootstrap
   ```

2. **Deploy infrastructure:**
   ```bash
   make setup
   ```

3. **Configure AWS credentials:**
   ```bash
   make credentials
   ```

4. **Upload files:**
   ```bash
   mkdir backup
   cp -r ~/Documents/important-stuff backup/
   make push
   ```

## Commands

- `make help` - Show all commands
- `make bootstrap` - Create Terraform state bucket (run once)
- `make setup` - Deploy S3 bucket and IAM user with remote state
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
- **State**: Terraform state stored in separate S3 bucket for safety

Files are stored in `./backup/` locally and synced to S3.