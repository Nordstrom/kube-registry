project_root := $(PWD)

include Makefile.variables
include Makefile.aws

build := build
export namespace := registry
# export service_name := portus
export cert_base_name := $(namespace).platform.prod.aws.cloud.nordstrom.net
KUBECTL := kubectl -n=$(namespace)
tls_hosts_base := registry.platform.prod.aws.cloud.nordstrom.net registry.svc.cluster.local registry.svc registry
export kube2iam_role := arn:aws:iam::051620159240:role/a0098/k8s/a0098-registry-production-docker_registry
s3_path_app_remote_state_path := applications/registry/terraform

namespace: $(build)/registry-namespace.yaml | kubectl
	kubectl apply -f $<

apply: apply/portus apply/docker

apply/docker: $(build)/docker-service.yaml $(build)/docker-configmap.yaml $(build)/docker-deployment.yaml $(build)/docker-ingress.yaml $(build)/nord-ca-certs-configmap.yaml | kubectl
	$(KUBECTL) apply $(foreach f,$^, -f $(f))

apply/portus: $(build)/portus-service.yaml $(build)/portus-configmap.yaml $(build)/portus-deployment.yaml $(build)/portus-ingress.yaml | kubectl
	# make namespace secret/db/portus secret/app/portus secret/cert/portus secret/ldap
	$(KUBECTL) apply $(foreach f,$^, -f $(f))

secret/db/portus: $(build)/portus/db-name $(build)/portus/db-hostname $(build)/portus/db-password $(build)/portus/db-username | kubectl
	$(KUBECTL) create secret generic portus-db \
	  --from-literal=db-name=$$(cat $(build)/portus/db-name) \
	  --from-literal=hostname=$$(cat $(build)/portus/db-hostname) \
	  --from-literal=password=$$(cat $(build)/portus/db-password) \
	  --from-literal=username=$$(cat $(build)/portus/db-username)

secret/app/portus: $(build)/portus/app-password $(build)/portus/app-secret-key-base | kubectl
	$(KUBECTL) create secret generic portus-app \
	  --from-literal=password=$$(cat $(build)/portus/app-password) \
	  --from-literal=secret-key-base=$$(cat $(build)/portus/app-secret-key-base)

secret/app/docker: $(build)/docker/ha-shared-secret | kubectl
	$(KUBECTL) create secret generic docker-app \
	  --from-literal=ha-shared-secret=$$(cat $(build)/docker/ha-shared-secret)

secret/cert/portus: $(build)/portus/portus.$(cert_base_name)-key.pem $(build)/portus/portus.$(cert_base_name).pem | kubectl
	$(KUBECTL) create secret tls portus.$(cert_base_name).tls --key=$< --cert=$(build)/portus/portus.$(cert_base_name).pem

secret/cert/docker: $(build)/docker/docker.$(cert_base_name)-key.pem $(build)/docker/docker.$(cert_base_name).pem | kubectl
	$(KUBECTL) create secret tls docker.$(cert_base_name).tls --key=$< --cert=$(build)/docker/docker.$(cert_base_name).pem

secret/ldap: $(build)/bind_dn $(build)/bind_password | kubectl
	$(KUBECTL) create secret generic ldap-search-credentials --from-file=bind-dn=$(build)/bind_dn --from-file=bind-password=$(build)/bind_password

.PRECIOUS: $(build)/%.yaml
$(build)/%.yaml: k8s/%.yaml.tmpl | sigil $(build)
	$(SIGIL) -p -f $< > $@

.PRECIOUS: $(build)/%/%.$(cert_base_name).json
$(build)/%/%.$(cert_base_name).json: ssl/csr.json.tmpl build/%.tls_hosts.json | sigil $(build)
	$(SIGIL) -p -f $< > $@

.PRECIOUS: $(build)/%/%.tls_hosts.json
$(build)/%/%.tls_hosts.json: | jq
	jq -ncCMRr '"$(foreach h,$(tls_hosts_base),$*.$(h)) $*" | split(" ")' > $@

.PRECIOUS: $(build)/%/%.$(cert_base_name)-key.pem $(build)/%/%.$(cert_base_name).csr
$(build)/%/%.$(cert_base_name)-key.pem $(build)/%/%.$(cert_base_name).csr: $(build)/%/%.$(cert_base_name).json | cfssl $(build)
	cfssl genkey $< | cfssljson -bare $(build)/$*.$(cert_base_name)

.PRECIOUS: $(build)/%/%.$(cert_base_name).response.json
$(build)/%/%.$(cert_base_name).response.json:  $(build)/%/%.$(cert_base_name).request.json | curl jq $(build)
	curl -X "POST" "https://certreq319.platform.prod.aws.cloud.nordstrom.net/getCert" \
	     -H "Content-Type: application/json" \
	     -u ${USER} \
	     -d@$< > $@

.PRECIOUS: $(build)/%/%.$(cert_base_name).request.json
$(build)/%/%.$(cert_base_name).request.json: $(build)/%/%.$(cert_base_name).csr | jq $(build)
	tr -d '\n' < $< | jq -CMR '{csr:.}' > $@

.PRECIOUS: $(build)/%/%.$(cert_base_name).pem
$(build)/%/%.$(cert_base_name).pem: $(build)/%/%.$(cert_base_name).response.json | curl jq $(build)
	jq -r '.Cert' $< > $@

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
