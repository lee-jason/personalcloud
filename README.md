# Personal Cloud Storage

Simple S3 Glacier Deep Archive backup solution with Terraform and Make.

## Quick Start
Login to AWS CLI with S3 access credentials

1. **Pull files**
   ```bash
   make pull
   ```

2. **Upload files:**
   ```bash
   make push
   ```


## How It Works

- **Push**: Files go directly to Glacier Deep Archive (~$1/TB/month)
- **Pull**: Requires restoration first (costs ~$0.02/GB + temp storage)
- **Storage**: Minimum 180 days, early deletion fees apply
- **State**: Terraform state stored in separate S3 bucket for safety

Files are stored in `./backup/` locally and synced to S3.