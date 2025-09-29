.PHONY: help bootstrap setup push pull restore status clean

BUCKET_NAME := "personal-glacier-cloud"
REGION := "us-east-1"
STATE_BUCKET := "personal-glacier-terraform-state"
LOCAL_PATH := ./backup
STORAGE_CLASS := DEEP_ARCHIVE
# Add variables at the top
CHECK_INTERVAL := 1800  # 30 minutes in seconds
MAX_WAIT_TIME := 258000 # 3 days

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
		--storage-class $(STORAGE_CLASS)
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
	aws s3 sync s3://$(BUCKET_NAME)/ $(LOCAL_PATH)/ --delete --force-glacier-transfer
	@echo "Download complete!"

# status: ## Check restoration status of files
# 	@if [ "$(BUCKET_NAME)" = "not-deployed" ]; then \
# 		echo "Error: Infrastructure not deployed. Run 'make setup' first."; \
# 		exit 1; \
# 	fi
# 	@echo "Checking restoration status..."
# 	aws s3api list-objects-v2 --bucket $(BUCKET_NAME) \
# 		--query 'Contents[?RestoreStatus].[Key,RestoreStatus]' \
# 		--output table

status: ## Check restoration status of files
	@if [ "$(BUCKET_NAME)" = "not-deployed" ]; then \
		echo "Error: Infrastructure not deployed. Run 'make setup' first."; \
		exit 1; \
	fi
	@echo "Checking restoration status..."
	@echo ""
	@echo "All objects in bucket:"
	aws s3api list-objects-v2 --bucket $(BUCKET_NAME) \
		--query 'Contents[].[Key,StorageClass,Size,LastModified]' \
		--output table
	@echo ""
	@echo "Objects with restore status:"
	@restored_objects=$$(aws s3api list-objects-v2 --bucket $(BUCKET_NAME) \
		--query 'Contents[?RestoreStatus]' --output json); \
	if [ "$$restored_objects" = "[]" ] || [ "$$restored_objects" = "null" ]; then \
		echo "No objects currently have restore status information."; \
		echo "This could mean:"; \
		echo "  - No restore has been initiated"; \
		echo "  - Restore is still in progress (check AWS console)"; \
		echo "  - Objects are already in Standard storage class"; \
	else \
		echo $$restored_objects | jq -r '.[] | [.Key, .RestoreStatus.OngoingRequest, .RestoreStatus.RestoreExpiryDate] | @tsv' | \
		awk 'BEGIN{printf "%-50s %-15s %s\n", "Key", "In Progress", "Expires"} {printf "%-50s %-15s %s\n", $$1, $$2, $$3}'; \
	fi

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

restore-and-pull: ## Restore files and automatically download when ready
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
		--restore-request Days=$$days,GlacierJobParameters="{Tier=Bulk}" || true; \
	echo "Restoration initiated. Will attempt download every $$(( $(CHECK_INTERVAL) / 60 )) minutes..."; \
	start_time=$$(date +%s); \
	attempt=1; \
	while true; do \
		current_time=$$(date +%s); \
		elapsed=$$((current_time - start_time)); \
		if [ $$elapsed -gt $(MAX_WAIT_TIME) ]; then \
			echo "Timeout reached ($$(( $(MAX_WAIT_TIME) / 3600 )) hours). Exiting."; \
			exit 1; \
		fi; \
		hours_elapsed=$$((elapsed / 3600)); \
		echo ""; \
		echo "$$(date): Attempt $$attempt ($$hours_elapsed hours elapsed)"; \
		echo "Attempting to download files..."; \
		mkdir -p $(LOCAL_PATH); \
		if aws s3 sync s3://$(BUCKET_NAME)/ $(LOCAL_PATH)/ --delete --force-glacier-transfer; then \
			echo ""; \
			echo "Download successful! All files restored and downloaded."; \
			break; \
		else \
			echo "Download failed - files not yet restored."; \
			echo "Waiting $$(( $(CHECK_INTERVAL) / 60 )) minutes before next attempt..."; \
			sleep $(CHECK_INTERVAL); \
			attempt=$$((attempt + 1)); \
		fi; \
	done