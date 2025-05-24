.PHONY: webhook reset lambda

webhook:
	@./webhook.sh

reset:
	@echo "Destroying existing infrastructure..."
	@terraform destroy -auto-approve
	@echo "Applying new infrastructure..."
	@terraform apply -auto-approve
	@echo "Infrastructure reset complete!"

lambda:
	@echo "zipping lambda functions"
	@cd lambdas/ && rm -rf task-executor-func.zip && rm -rf task-scheduling-func.zip
	@cd lambdas/ && zip -r task-executor-func.zip node_modules/ task-executor.js 
	@cd lambdas/ && zip -r task-scheduling-func.zip node_modules/ task-scheduling-api.js
	@echo "all lambdas zipped" 