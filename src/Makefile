RESOURCE_GROUP	?= kinmugi-bicep01
LOCATION	?= eastus2
ADMIN_USERNAME	?= linuxadmin
ADMIN_PASSWORD	?= 			#'placeholder should be overwrite.'
VM_SIZE		?=  Standard_B1s

BICEP		:= bicep
AZ		:= az
DEPLOY_NAME	= $(shell date +'DEPLOY-%d%H%M%S')

export AZURE_CORE_OUTPUT = table
## export AZURE_CORE_OUTPUT = json

help:           	## Show this help.
	@sed -ne '/@sed/!s/## //p' $(MAKEFILE_LIST)

%.json : %.bicep
	@$(BICEP) build $<

main.json: *.bicep

create-rg:
	@if [ "$(CMD)" = "create" ] ; then \
		$(AZ) group create -g $(RESOURCE_GROUP) -l $(LOCATION) -o none; \
	else \
		echo 'Info: CMD=$(CMD) skip create $(RESOURCE_GROUP).'; \
	fi

what-if:		## Dry run deploy to Azure
	@$(MAKE) az-deploy CMD=what-if

deploy:	        	## Deploy to Azure
	@$(MAKE) az-deploy CMD=create


az-deploy: create-rg main.json
	@$(AZ) deployment group $(CMD) -g $(RESOURCE_GROUP) -n $(DEPLOY_NAME) \
		-f main.json \
		-p vmSize=$(VM_SIZE) \
		adminUsername=$(ADMIN_USERNAME) \
 		adminPassword=$(ADMIN_PASSWORD)

az-account:
	$(AZ) account list
