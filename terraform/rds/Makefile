ifndef platform_env
$(error platform_env is undefined)
endif

project_root := $(realpath $(PWD)/../..)
build := $(PWD)/build.$(platform_env)
aws_resource_name_prefix := $(cloud_team_id)-$(platform_env)
s3_path_app_remote_state_path = $(s3_path_app_remote_state_path_rds)
instance_name := portus-db

include $(project_root)/Makefile.variables
include $(project_root)/Makefile.terraform

$(build)/master_db_username: | $(build)
	@printf 'u%s' "$$(openssl rand -hex 4)" > $@

$(build)/master_db_password: | $(build)
	@printf 'p%s' "$$(openssl rand -hex 16)" > $@

$(build)/terraform.tfvars: $(build)/master_db_username
$(build)/terraform.tfvars: $(build)/master_db_password
$(build)/terraform.tfvars: Makefile
$(build)/terraform.tfvars: | $(build)
	printf '# terraform.tfvars: this file is machine generated. built at %s\n' "$$(date)" > $@
	@printf '%s = "%s"\n' aws_region '$(aws_region)' >> $@
	@printf '%s = "%s"\n' vpc_id '$(vpc_id)' >> $@
	@printf '%s = "%s"\n' cloud_team_id '$(cloud_team_id)' >> $@
	@printf '%s = "%s"\n' cost_center '$(cost_center)' >> $@
	@printf '%s = "%s"\n' aws_resource_name_prefix '$(aws_resource_name_prefix)' >> $@
	@printf '%s = "%s"\n' s3_bucket_name '$(s3_bucket_name)' >> $@
	@printf '%s = %s\n' db_instances_subnet_id_list '$(db_instances_subnet_id_list)' >> $@
	@printf '%s = %s\n' rds_security_group_allowed_ingress_cidr_ranges '$(rds_security_group_allowed_ingress_cidr_range_list)' >> $@
	@printf '%s = "%s"\n' instance_name '$(instance_name)' >> $@
	@printf '%s = "%s"\n' master_db_username "$$(cat $(build)/master_db_username)" >> $@
	@printf '%s = "%s"\n' master_db_password "$$(cat $(build)/master_db_password)" >> $@

$(build):
	mkdir -p $@

clean:
	rm -rf $(build)
