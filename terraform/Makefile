apply: apply/iam apply/rds apply/mysql

apply/%:
	cd $*; make apply

plan: plan/iam plan/rds plan/mysql

plan/%:
	cd $*; make plan

destroy: destroy/mysql destroy/rds destroy/iam

destroy/%:
	cd $*; make destroy
