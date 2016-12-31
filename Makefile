project_root := $(PWD)

include Makefile.variables
include Makefile.aws

export build := $(project_root)/build.$(platform_env)
export namespace := registry
export kube2iam_role := arn:aws:iam::051620159240:role/a0098/k8s/a0098-registry-production-docker_registry
export cert_base_name_external := $(namespace).$(platform_domain_name)
export cert_base_name_internal := $(namespace).svc.$(cluster_dns_domain)
s3_path_app_remote_state_path := applications/registry/terraform
KUBECTL := kubectl -n=$(namespace)
TERRAFORM := terraform

namespace: $(build)/registry-namespace.yaml | kubectl
	kubectl apply -f $<

apply: apply/portus apply/docker-registry apply/registry-monitor

apply/docker-registry: $(build)/docker-registry-service.yaml $(build)/docker-registry-configmap.yaml $(build)/docker-registry-deployment.yaml $(build)/docker-registry-ingress.yaml $(build)/nord-ca-certs-configmap.yaml | kubectl
	$(KUBECTL) apply $(foreach f,$^, -f $(f))

apply/portus: $(build)/portus-service.yaml $(build)/portus-configmap.yaml $(build)/portus-deployment.yaml $(build)/portus-ingress.yaml | kubectl
	# make namespace secret/db/portus secret/app/portus secret/cert/portus secret/ldap
	$(KUBECTL) apply $(foreach f,$^, -f $(f))

apply/registry-monitor: $(build)/registry-monitor-deployment.yaml | kubectl
	$(KUBECTL) apply $(foreach f,$^, -f $(f))

secrets/portus: $(build)/portus-db-secret.yaml $(build)/portus-secret.yaml $(build)/portus-ldap-secret.yaml | kubectl
	$(KUBECTL) apply $(foreach f,$^, -f $(f))

secrets/docker: $(build)/docker-registry-secret.yaml | kubectl
	$(KUBECTL) apply $(foreach f,$^, -f $(f))

secrets/registry-monitor: $(build)/registry-monitor-secret.yaml | kubectl
	$(KUBECTL) apply $(foreach f,$^, -f $(f))

secrets/docker/certs: $(build)/docker.$(cert_base_name_external).tls-secret.yaml $(build)/docker.$(cert_base_name_internal).tls-secret.yaml | kubectl
	$(KUBECTL) apply $(foreach f,$^, -f $(f))

secrets/portus/certs: $(build)/portus.$(cert_base_name_external).tls-secret.yaml $(build)/portus.$(cert_base_name_internal).tls-secret.yaml | kubectl
	$(KUBECTL) apply $(foreach f,$^, -f $(f))

.PRECIOUS: $(build)/%.yaml
$(build)/%.yaml: k8s/%.yaml.tmpl | sigil $(build)
	@$(SIGIL) -p -f $< > $@

.PRECIOUS: $(build)/%.tls-secret.yaml.tmpl
$(build)/%.tls-secret.yaml: k8s/tls-secret.yaml.tmpl $(build)/tls/%.crt
	@echo "Templating $@"
	@tls_secret_name='$*' \
	  $(SIGIL) -p -f $< > $@

$(build)/tls/%.crt:
	cd tls; make $@

$(build)/portus-secret.yaml: k8s/portus-secret.yaml.tmpl $(build)/portus/app-password $(build)/portus/app-secret-key-base | kubectl
	@password='$(shell cat $(build)/portus/app-password | base64)' \
	  secret_key_base='$(shell cat $(build)/portus/app-secret-key-base | base64)' \
	  $(SIGIL) -p -f $< > $@

$(build)/registry-monitor-secret.yaml: k8s/registry-monitor-secret.yaml.tmpl $(build)/registry-monitor/username $(build)/registry-monitor/password | kubectl
	@username='$(shell cat $(build)/registry-monitor/username | base64)' \
	  password='$(shell cat $(build)/registry-monitor/password | base64)' \
	  $(SIGIL) -p -f $< > $@

$(build)/portus-db-secret.yaml: k8s/portus-db-secret.yaml.tmpl $(build)/portus/db-name $(build)/portus/db-hostname $(build)/portus/db-password $(build)/portus/db-username | kubectl
	@db_name='$(shell cat $(build)/portus/db-name | base64)' \
	  hostname='$(shell cat $(build)/portus/db-hostname | base64)' \
	  password='$(shell cat $(build)/portus/db-password | base64)' \
	  username='$(shell cat $(build)/portus/db-username | base64)' \
	  $(SIGIL) -p -f $< > $@

$(build)/portus-ldap-secret.yaml: k8s/portus-ldap-secret.yaml.tmpl $(build)/portus/bind_dn $(build)/portus/bind_password | kubectl
	@bind_dn='$(shell cat $(build)/portus/bind_dn | base64)' \
	  bind_password='$(shell cat  $(build)/portus/bind_password | base64)' \
	  $(SIGIL) -p -f $< > $@

$(build)/docker-registry-secret.yaml: k8s/docker-registry-secret.yaml.tmpl $(build)/docker/ha-shared-secret | kubectl
	@ha_shared_secret='$(shell cat $(build)/docker/ha-shared-secret)' \
	  $(SIGIL) -p -f $< > $@

$(build)/docker/ha-shared-secret: | $(build)/docker
	@openssl rand -hex 16 | tr -d '\n' > $@

$(build)/portus/bind_dn: | $(build)/portus
	@[[ -n "${LDAP_BIND_DN}" ]] || (echo "LDAP_BIND_DN must be set" && exit 1)
	jq -nCMRr 'env.LDAP_BIND_DN' | tr -d '\n' > $@

$(build)/portus/bind_password: | $(build)/portus
	@[[ -n "${LDAP_BIND_PASSWORD}" ]] || (echo "LDAP_BIND_PASSWORD must be set" && exit 1)
	jq -nCMRr 'env.LDAP_BIND_PASSWORD' | tr -d '\n' > $@

$(build)/portus/db-hostname: $(build)/portus/rds.tfstate
	@$(TERRAFORM) output -state=$< address | tr -d '\n' > $@

$(build)/portus/db-name: $(build)/portus/mysql.tfstate
	@$(TERRAFORM) output -state=$< database | tr -d '\n' > $@

$(build)/portus/db-password: $(build)/portus/mysql.tfstate
	@$(TERRAFORM) output -state=$< password | tr -d '\n' > $@

$(build)/portus/db-username: $(build)/portus/mysql.tfstate
	@$(TERRAFORM) output -state=$< username | tr -d '\n' > $@

$(build)/portus/app-password: | $(build)
	@printf 'p%s' "$$(openssl rand -hex 16)" | tr -d '\n' > $@

$(build)/portus/app-secret-key-base: | $(build)
	@printf 'p%s' "$$(openssl rand -hex 16)" | tr -d '\n' > $@

$(build)/portus/rds.tfstate: | $(build)/portus # aws
	@$(AWS) s3 cp s3://$(s3_bucket_name)/$(s3_path_app_remote_state_path)/rds.tfstate $@

$(build)/portus/mysql.tfstate: | $(build)/portus # aws
	@$(AWS) s3 cp s3://$(s3_bucket_name)/$(s3_path_app_remote_state_path)/mysql.tfstate $@

$(build)/registry-monitor/username: | $(build)/registry-monitor
	@[[ -n "${REGISTRY_MONITOR_USERNAME}" ]] || (echo "REGISTRY_MONITOR_USERNAME must be set" && exit 1)
	jq -nCMRr 'env.REGISTRY_MONITOR_USERNAME' | tr -d '\n' > $@

$(build)/registry-monitor/password: | $(build)/registry-monitor
	@[[ -n "${REGISTRY_MONITOR_PASSWORD}" ]] || (echo "REGISTRY_MONITOR_PASSWORD must be set" && exit 1)
	jq -nCMRr 'env.REGISTRY_MONITOR_PASSWORD' | tr -d '\n' > $@

$(build) $(build)/portus $(build)/docker $(build)/registry-monitor:
	mkdir -p $@

clean/portus:
	rm -rf $(build)/portus

clean/docker:
	rm -rf $(build)/docker

clean:
	rm -rf $(build)
