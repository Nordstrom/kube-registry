apply: apply/iam apply/rds apply/mysql

apply/iam:
apply/rds:
apply/mysql: apply/rds
apply/%:
	cd $*; make apply

plan: plan/iam plan/rds plan/mysql

plan/iam:
plan/rds:
plan/mysql: plan/rds
plan/%:
	cd $*; make plan

destroy: destroy/iam destroy/rds destroy/mysql

destroy/iam:
destroy/rds:
destroy/mysql: destroy/rds
destroy/%:
	cd $*; make destroy
