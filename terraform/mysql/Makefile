ifndef platform_env
$(error platform_env is undefined)
endif

project_root := $(realpath $(PWD)/../..)
build := $(PWD)/build.$(platform_env)
s3_path_app_remote_state_path = $(s3_path_app_remote_state_path_mysql)
db_name = portus_$(platform_env)
namespace := registry
KUBECTL := kubectl -n$(namespace)

include $(project_root)/Makefile.variables
include $(project_root)/Makefile.terraform

$(build)/db_username: | $(build)
	@printf 'u%s' "$$(openssl rand -hex 4)" > $@

$(build)/db_password: | $(build)
	@printf 'p%s' "$$(openssl rand -hex 16)" > $@

$(build)/mysql_endpoint: $(build)/rds.tfstate
	@$(TERRAFORM) output -state=$< endpoint > $@
	#@echo "172.20.160.133:3306" > $@

$(build)/master_username: $(build)/rds.tfstate
	@$(TERRAFORM) output -state=$< username > $@

$(build)/master_password: $(build)/rds.tfstate
	@$(TERRAFORM) output -state=$< password > $@

# TODO: use terraform_remote_state. I encountered problems and went for this work-around
$(build)/rds.tfstate: | $(build) # aws
	@$(AWS) s3 cp s3://$(s3_bucket_name)/$(s3_path_app_remote_state_path_rds) $@

$(build)/terraform.tfvars: $(build)/db_username
$(build)/terraform.tfvars: $(build)/db_password
$(build)/terraform.tfvars: $(build)/mysql_endpoint
$(build)/terraform.tfvars: $(build)/master_username
$(build)/terraform.tfvars: $(build)/master_password
$(build)/terraform.tfvars: Makefile
$(build)/terraform.tfvars: | $(build)
	echo "# terraform.tfvars: this file is machine generated. built at $$(date)" >> $@
	@printf '%s = "%s"\n' s3_bucket_name '$(s3_bucket_name)' >> $@
	@printf '%s = "%s"\n' rds_remote_state_location '$(s3_path_app_remote_state_path_rds)' >> $@
	@printf '%s = "%s"\n' db_name '$(db_name)' >> $@
	@printf '%s = "%s"\n' db_username "$$(cat $(build)/db_username)" >> $@
	@printf '%s = "%s"\n' db_password "$$(cat $(build)/db_password)" >> $@
	@printf '%s = "%s"\n' mysql_endpoint "$$(cat $(build)/mysql_endpoint)" >> $@
	@printf '%s = "%s"\n' master_username "$$(cat $(build)/master_username)" >> $@
	@printf '%s = "%s"\n' master_password "$$(cat $(build)/master_password)" >> $@

$(build):
	mkdir -p $@

clean:
	rm -rf $(build)
