project_root := $(realpath $(PWD)/..)

include $(project_root)/Makefile.variables
include $(project_root)/Makefile.aws

build := $(project_root)/build.$(platform_env)/tls
export namespace := registry
external_tls_hosts_base := registry.$(platform_domain_name)
internal_tls_hosts_base := registry.svc.$(cluster_dns_domain) registry.svc registry
KUBECTL := kubectl -n=$(namespace)
export kube2iam_role := arn:aws:iam::051620159240:role/a0098/k8s/a0098-registry-production-docker_registry
s3_path_app_remote_state_path := $(platform_env)/applications/registry/terraform

.PRECIOUS: $(build)/%.crt
$(build)/%.crt: $(build)/%-bare.crt $(build)/%-ca.crt | $(build)
	cat $^ > $@

.PRECIOUS: $(build)/%-bare.crt
$(build)/%-bare.crt: $(build)/%.response.json | $(build) curl jq
	jq -r '.Cert' $< > $@

.PRECIOUS: $(build)/%-ca.crt
$(build)/%-ca.crt:
	$(error "Please place the appropriate CA chain at $@")
	# @echo "Please place the appropriate CA chain at $@" && exit 1

.PRECIOUS: $(build)/%.response.json
$(build)/%.response.json:  $(build)/%.request.json | $(build) curl jq
	curl -X "POST" "https://certreq319.platform.prod.aws.cloud.nordstrom.net/getCert" \
	     -H "Content-Type: application/json" \
	     -u ${USER} \
	     -d@$< > $@

.PRECIOUS: $(build)/%.request.json
$(build)/%.request.json: $(build)/%.csr | jq $(build)
	# cat $< | jq -sCMR '{csr:.}' > $@ # escaped newlines ('\n')
	tr -d '\n' < $< | jq -CMR '{csr:.}' > $@ # strip newlines

.PRECIOUS: $(build)/%.key $(build)/%.csr
$(build)/%.key $(build)/%.csr: $(build)/%-csr.json | $(build) cfssl
	cfssl genkey $< | cfssljson -bare $(build)/$*
	cp $(build)/$*-key.pem $(build)/$*.key

.PRECIOUS: $(build)/%.$(cluster_dns_domain)-csr.json
$(build)/%.$(cluster_dns_domain)-csr.json: export organization := Nordstrom
$(build)/%.$(cluster_dns_domain)-csr.json: export locality := Seattle
$(build)/%.$(cluster_dns_domain)-csr.json: export state := Washington
$(build)/%.$(cluster_dns_domain)-csr.json: csr.json.tmpl $(build)/%.$(cluster_dns_domain)-hosts.json | $(build) sigil
	@cert_name=$*.$(cluster_dns_domain) \
	  hosts='$(shell cat $(build)/$*.$(cluster_dns_domain)-hosts.json)' \
	  $(SIGIL) -p -f $< > $@

# .PRECIOUS: $(build)/%.$(platform_domain_name)-csr.json
# $(build)/%.$(platform_domain_name)-csr.json: csr.json.tmpl $(build)/%.$(platform_domain_name)-hosts.json | $(build) sigil
# 	@cert_name=$*.$(platform_domain_name) \
# 	  organization='$(shell cat $(build)/$*.$(platform_domain_name)-hosts.json)' \
# 	  hosts='$(shell cat $(build)/$*.$(platform_domain_name)-hosts.json)' \
# 	  $(SIGIL) -p -f $< > $@

$(build)/portus.registry.$(platform_domain_name)-csr.json: export cert_name := portus.$(platform_domain_name)
$(build)/portus.registry.$(platform_domain_name)-csr.json: export organization := Nordstrom
$(build)/portus.registry.$(platform_domain_name)-csr.json: export locality := Seattle
$(build)/portus.registry.$(platform_domain_name)-csr.json: export state := Washington
$(build)/portus.registry.$(platform_domain_name)-csr.json: csr.json.tmpl $(build)/portus.registry.$(platform_domain_name)-hosts.json | $(build) sigil
	@hosts='$(shell cat $(build)/portus.registry.$(platform_domain_name)-hosts.json)' \
	  $(SIGIL) -p -f $< > $@

$(build)/docker.registry.$(platform_domain_name)-csr.json: export cert_name := docker.$(platform_domain_name)
$(build)/docker.registry.$(platform_domain_name)-csr.json: export organization := NIHC Inc
$(build)/docker.registry.$(platform_domain_name)-csr.json: export locality := Portland
$(build)/docker.registry.$(platform_domain_name)-csr.json: export state := Oregon
$(build)/docker.registry.$(platform_domain_name)-csr.json: csr.json.tmpl $(build)/docker.registry.$(platform_domain_name)-hosts.json | $(build) sigil
	@hosts='$(shell cat $(build)/docker.registry.$(platform_domain_name)-hosts.json)' \
	  $(SIGIL) -p -f $< > $@

.PRECIOUS: $(build)/%.$(cluster_dns_domain)-hosts.json
$(build)/%.registry.svc.$(cluster_dns_domain)-hosts.json: | jq
	jq -ncCMRr '"$(foreach h,$(internal_tls_hosts_base),$*.$(h)) $*" | split(" ")' > $@

.PRECIOUS: $(build)/%.$(platform_domain_name)-hosts.json
$(build)/%.registry.$(platform_domain_name)-hosts.json: | jq
	jq -ncCMRr '"$(foreach h,$(external_tls_hosts_base),$*.$(h))" | split(" ")' > $@

$(build):
	mkdir -p $@

clean:
	rm -rf $(build)
