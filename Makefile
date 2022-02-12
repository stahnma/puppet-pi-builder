
.EXPORT_ALL_VARIABLES:

WORKDIR=$(shell pwd)
REMOTE_HOST=gunn
NO_PXP_AGENT=true
VANAGON_USE_MIRRORS=n
VANAGON_LOCATION=file:///$(WORKDIR)/vanagon
RUNTIME_VERSION=$(shell [ -e puppet-runtime/output/*.json ] && jq -r '.version' `ls -tr puppet-runtime/output/*.json` || echo "FALSE")
GEM_HOME=./vendor

help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

populate:
	@if [ "$(RUNTIME_VERSION)" == "FALSE" ] ; then \
		echo "Build the runtime successsfully first." ; \
		exit 4; \
	fi
	@echo "Found runtime version $(RUNTIME_VERSION)."
	@echo '{"location":"file://$(WORKDIR)/puppet-runtime/output","version":"$(RUNTIME_VERSION)"}' > puppet-runtime.json
	@cat puppet-runtime.json
	mv puppet-runtime.json $(WORKDIR)/puppet-agent/configs/components


runtime: clean-remote setup ## Build the runtime artifact
	(cd puppet-runtime; time bundle exec vanagon build agent-runtime-main debian-11-armhf $(REMOTE_HOST))

agent: clean-remote populate ## Build the puppet-agent
	$(MAKE) clean-remote
	(cd puppet-agent; time bundle exec vanagon build puppet-agent debian-11-armhf $(REMOTE_HOST))

clean:
	rm -rf puppet-agent/vendor puppet-runtime/vendor vanagon/vendor

artifact-clean: ## Remove artifact directories
	rm -rf puppet-agent/output puppet-runtime/output

clobber: ## Remove all checkouts of agent, runtime and vanagon (this is destructive)
	rm -rf puppet-agent puppet-runtime vanagon

clean-remote: ## Clean remote machine you're building on
	ssh -o StrictHostKeyChecking=no root@$(REMOTE_HOST) "rm -rf /opt/puppetlabs /var/tmp/tmp.* /etc/puppetlabs"

vanagon-clone:
	if [ ! -d vanagon ]; then \
		git clone -o puppetlabs https://github.com/puppetlabs/vanagon && cd vanagon && bundle ; fi

runtime-clone:
	if [ ! -d puppet-runtime ]; then \
		git clone -o stahnma https://github.com/stahnma/puppet-runtime && cd puppet-runtime && git checkout mainstream && bundle ; fi

agent-clone:
	if [ ! -d puppet-agent ]; then \
		git clone -o stahnma http://github.com/stahnma/puppet-agent && cd puppet-agent && git checkout add-bullseye-armhf && bundle ; fi

setup: vanagon-clone runtime-clone agent-clone ## Clone the projects needed to build

package: setup runtime agent ## Build the whole agent package and place it locally
	mv puppet-agent/output/deb ./pkg

validate-remote: ## Ensure you can connect to $(REMOTE_HOST)
	@echo "Validating connection to $(REMOTE_HOST)"
	ssh -o StrictHostKeyChecking=no root@$(REMOTE_HOST) uptime
