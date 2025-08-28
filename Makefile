.PHONY: help setup push pull restore status clean

BUCKET_NAME := $(shell terraform output -raw bucket_name 2>/dev/null || echo "not-deployed")
REGION := $(shell terraform output -raw bucket_region 2>/dev/null || echo "us-west-2")
LOCAL_PATH := ./backup
STORAGE_CLASS := DEEP_ARCHIVE

help: ## Show this help message
	@echo "Personal Cloud Storage Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

setup: ## Deploy infrastructure with Terraform
	@echo "Deploying S3 Glacier infrastructure..."
	terraform init
	terraform plan
	terraform apply
	@echo ""
	@echo "Setup complete! Run 'make credentials' to configure AWS CLI"

credentials: ## Display AWS credentials setup instructions
	@echo "Configure AWS CLI with these credentials:"
	@echo ""
	@echo "aws configure set aws_access_key_id $$(terraform output -raw iam_access_key_id)"
	@echo "aws configure set aws_secret_access_key $$(terraform output -raw iam_secret_access_key)"
	@echo "aws configure set region $(REGION)"
	@echo ""
	@echo "Or create a named profile:"
	@echo "aws configure set aws_access_key_id $$(terraform output -raw iam_access_key_id) --profile personalcloud"
	@echo "aws configure set aws_secret_access_key $$(terraform output -raw iam_secret_access_key) --profile personalcloud"
	@echo "aws configure set region $(REGION) --profile personalcloud"

push: ## Upload local files to S3 Glacier Deep Archive
	@if [ "$(BUCKET_NAME)" = "not-deployed" ]; then \
		echo "Error: Infrastructure not deployed. Run 'make setup' first."; \
		exit 1; \
	fi
	@echo "Syncing $(LOCAL_PATH) to s3://$(BUCKET_NAME)/ (Deep Archive)..."
	aws s3 sync $(LOCAL_PATH)/ s3://$(BUCKET_NAME)/ \
		--storage-class $(STORAGE_CLASS) \
		--delete
	@echo "Upload complete!"

restore: ## Initiate restoration of all files (12-48 hour delay)
	@if [ "$(BUCKET_NAME)" = "not-deployed" ]; then \
		echo "Error: Infrastructure not deployed. Run 'make setup' first."; \
		exit 1; \
	fi
	@echo "Initiating bulk restoration of all files (this will take 12-48 hours)..."
	@read -p "Restore for how many days? (1-365): " days; \
	aws s3api list-objects-v2 --bucket $(BUCKET_NAME) --query 'Contents[].Key' --output text | \
	tr '\t' '\n' | \
	xargs -I {} aws s3api restore-object \
		--bucket $(BUCKET_NAME) \
		--key {} \
		--restore-request Days=$$days,GlacierJobParameters="{Tier=Bulk}"
	@echo "Restoration initiated. Check status with 'make status'"

pull: ## Download files from S3 (requires files to be restored first)
	@if [ "$(BUCKET_NAME)" = "not-deployed" ]; then \
		echo "Error: Infrastructure not deployed. Run 'make setup' first."; \
		exit 1; \
	fi
	@echo "Downloading from s3://$(BUCKET_NAME)/ to $(LOCAL_PATH)..."
	@mkdir -p $(LOCAL_PATH)
	aws s3 sync s3://$(BUCKET_NAME)/ $(LOCAL_PATH)/ --delete
	@echo "Download complete!"

status: ## Check restoration status of files
	@if [ "$(BUCKET_NAME)" = "not-deployed" ]; then \
		echo "Error: Infrastructure not deployed. Run 'make setup' first."; \
		exit 1; \
	fi
	@echo "Checking restoration status..."
	aws s3api list-objects-v2 --bucket $(BUCKET_NAME) \
		--query 'Contents[?RestoreStatus].[Key,RestoreStatus]' \
		--output table
