.PHONY: help bootstrap setup push pull restore status clean

BUCKET_NAME := "personal-glacier-cloud"
REGION := "us-east-1"
STATE_BUCKET := "personal-glacier-terraform-state"
LOCAL_PATH := ./backup
STORAGE_CLASS := DEEP_ARCHIVE

help: ## Show this help message
	@echo "Personal Cloud Storage Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

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

info: ## Show bucket information
	@if [ "$(BUCKET_NAME)" = "not-deployed" ]; then \
		echo "Error: Infrastructure not deployed. Run 'make setup' first."; \
		exit 1; \
	fi
	@echo "Bucket: $(BUCKET_NAME)"
	@echo "Region: $(REGION)"
	@echo "Local Path: $(LOCAL_PATH)"
	@echo "Storage Class: $(STORAGE_CLASS)"
	@echo ""
	@echo "Bucket contents:"
	aws s3 ls s3://$(BUCKET_NAME)/ --recursive --human-readable

clean: ## Destroy infrastructure (WARNING: This deletes everything!)
	@echo "WARNING: This will destroy all infrastructure and data!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		terraform destroy; \
	else \
		echo "Cancelled."; \
	fi
