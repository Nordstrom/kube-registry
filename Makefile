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

namespace: $(build)/registry-namespace.yaml | kubectl
	kubectl apply -f $<

apply: apply/portus apply/docker

apply/docker: $(build)/docker-registry-service.yaml $(build)/docker-registry-configmap.yaml $(build)/docker-registry-deployment.yaml $(build)/docker-registry-ingress.yaml $(build)/nord-ca-certs-configmap.yaml | kubectl
	$(KUBECTL) apply $(foreach f,$^, -f $(f))

apply/portus: $(build)/portus-service.yaml $(build)/portus-configmap.yaml $(build)/portus-deployment.yaml $(build)/portus-ingress.yaml | kubectl
	# make namespace secret/db/portus secret/app/portus secret/cert/portus secret/ldap
	$(KUBECTL) apply $(foreach f,$^, -f $(f))

secret/db/portus: $(build)/portus/db-name $(build)/portus/db-hostname $(build)/portus/db-password $(build)/portus/db-username | kubectl
	$(KUBECTL) create secret generic portus-db \
	  --from-file=db-name=$(build)/portus/db-name \
	  --from-file=hostname=$(build)/portus/db-hostname \
	  --from-file=password=$(build)/portus/db-password \
	  --from-file=username=$(build)/portus/db-username

secret/app/portus: $(build)/portus/app-password $(build)/portus/app-secret-key-base | kubectl
	$(KUBECTL) create secret generic portus-app \
	  --from-file=password=$(build)/portus/app-password \
	  --from-file=secret-key-base=$(build)/portus/app-secret-key-base

secret/app/docker: $(build)/docker/ha-shared-secret | kubectl
	$(KUBECTL) create secret generic docker-app --from-file=ha-shared-secret=$(build)/docker/ha-shared-secret

secret/cert/docker: $(build)/docker.$(cert_base_name_external).tls-secret.yaml $(build)/docker.$(cert_base_name_internal).tls-secret.yaml | kubectl
	$(KUBECTL) apply $(foreach f,$^, -f $(f))

secret/cert/portus: $(build)/portus.$(cert_base_name_external).tls-secret.yaml $(build)/portus.$(cert_base_name_internal).tls-secret.yaml | kubectl
	$(KUBECTL) apply $(foreach f,$^, -f $(f))

secret/ldap: $(build)/bind_dn $(build)/bind_password | kubectl
	$(KUBECTL) create secret generic ldap-search-credentials --from-file=bind-dn=$(build)/bind_dn --from-file=bind-password=$(build)/bind_password

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

$(build)/bind_dn: | $(build)
	@[[ -n "${LDAP_BIND_DN}" ]] || (echo "LDAP_BIND_DN must be set" && exit 1)
	jq -nCMRr 'env.LDAP_BIND_DN' | tr -d '\n' > $@

$(build)/bind_password: | $(build)
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

$(build)/portus/rds.tfstate: | $(build) # aws
	@$(AWS) s3 cp s3://$(s3_bucket_name)/$(s3_path_app_remote_state_path)/rds.tfstate $@

$(build)/portus/mysql.tfstate: | $(build) # aws
	@$(AWS) s3 cp s3://$(s3_bucket_name)/$(s3_path_app_remote_state_path)/mysql.tfstate $@

$(build)/portus/app-password: | $(build)
	@printf 'p%s' "$$(openssl rand -hex 16)" | tr -d '\n' > $@

$(build)/portus/app-secret-key-base: | $(build)
	@printf 'p%s' "$$(openssl rand -hex 16)" | tr -d '\n' > $@

$(build)/docker/ha-shared-secret: | $(build)
	@openssl rand -hex 16 | tr -d '\n' > $@

$(build):
	mkdir -p $@

clean:
	rm -rf $(build)
