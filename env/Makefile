# env parameters
ENV ?=
REGION ?= "us-central1"
ZONE ?= "us-central1-a"
BUILDER_INSTANCE ?= n1-standard-2
CLUSTER_INSTANCE ?= n1-standard-4
NODES ?= 3
CREDS ?=

# binaries to use
TELE ?= tele
TF ?= terraform

# purpose label to tag all GCE resources with, will be used for billing
PURPOSE ?= training

# directory with terraform scripts
TF_DIR ?= terraform

# path to the public SSH key file to put on GCE instances
SSH_KEY_PATH ?=

# exported terraform variables
TF_VAR_node_tag := $(ENV)
TF_VAR_purpose := $(PURPOSE)
TF_VAR_ssh_key_path := $(SSH_KEY_PATH)
TF_VAR_region := $(REGION)
TF_VAR_zone := $(ZONE)
TF_VAR_credentials := $(CREDS)
TF_VAR_builder_instance_type := $(BUILDER_INSTANCE)
TF_VAR_cluster_instance_type := $(CLUSTER_INSTANCE)
TF_VAR_nodes := $(NODES)

export

#
# up sets up training environment with specified name.
#
.PHONY: up
up: check-env check-ssh-key init
	cd ${TF_DIR} && ${TF} apply -auto-approve

#
# down tears down training environment with specified name.
#
.PHONY: down
down: check-env refresh
	cd ${TF_DIR} && ${TF} destroy -auto-approve

#
# out displays output variables for environment with specified name.
#
.PHONY: out
out: check-env refresh

#
# csv outputs IPs of nodes of the specified environment as comma-separated values.
#
.PHONY: csv
csv: check-env
	@cd ${TF_DIR} && ${TF} output csv

#
# refresh refreshes local terraform state from S3 bucket.
#
.PHONY: refresh
refresh: check-env init
	cd ${TF_DIR} && ${TF} refresh

#
# init initializes a single training environment.
#
.PHONY: init
init: check-env
	cd ${TF_DIR} && ${TF} init -reconfigure \
		-backend-config="path=../$(ENV).tfstate"


#
# check-env makes sure ENV environment variable is set.
#
.PHONY: check-env
check-env:
	@if [ -z "$(ENV)" ]; then \
	  echo "ENV is not set"; exit 1; \
	fi;

#
# check-ssh-key makes sure SSH_KEY_PATH environment variable is set.
#
.PHONY: check-ssh-key
check-ssh-key:
	@if [ -z "$(SSH_KEY_PATH)" ]; then \
	  echo "SSH_KEY_PATH is not set"; exit 1; \
	fi;
