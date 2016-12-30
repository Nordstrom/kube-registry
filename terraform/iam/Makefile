ifndef platform_env
$(error platform_env is undefined)
endif

project_root := $(realpath $(PWD)/../..)
build := $(PWD)/build.$(platform_env)
aws_resource_name_prefix := $(cloud_team_id)-registry-$(platform_env)
s3_path_app_remote_state_path = $(s3_path_app_remote_state_path_iam)

include $(project_root)/Makefile.variables
include $(project_root)/Makefile.terraform

$(build)/%.json: %.json.tmpl | sigil $(build)
	@echo "Templating $@"
	@$(SIGIL) -p -f "$<" > "$@"

$(build)/terraform.tfvars: $(build)/iam_role_policy.json
$(build)/terraform.tfvars: $(build)/assume_role_policy.json
$(build)/terraform.tfvars: Makefile
$(build)/terraform.tfvars: | $(build)
	printf '# terraform.tfvars: this file is machine generated. built at %s\n' "$$(date)" > $@
	@printf '%s = "%s"\n' aws_region '$(aws_region)' >> $@
	@printf '%s = "%s"\n' vpc_id '$(vpc_id)' >> $@
	@printf '%s = "%s"\n' cloud_team_id '$(cloud_team_id)' >> $@
	@printf '%s = "%s"\n' cost_center '$(cost_center)' >> $@
	@printf '%s = "%s"\n' aws_resource_name_prefix '$(aws_resource_name_prefix)' >> $@
	@printf '%s = "%s"\n' build_dir '$(build)' >> $@

$(build):
	mkdir -p $@

clean:
	rm -rf $(build)
