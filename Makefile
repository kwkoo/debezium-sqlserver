PROJ=demo

BASE:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

,PHONY: deploy
deploy: check-login strimzi db deploy-sqlpad kafka debezium
	@echo "installation complete"

,PHONY: check-login
check-login:
	oc whoami

.PHONY: strimzi
strimzi:
	@echo "installing Strimzi..."
	oc apply -n openshift-operators -f $(BASE)/yaml/streams-operator.yaml

.PHONY: kafka
kafka:
	@oc new-project $(PROJ) || echo "$(PROJ) already exists"
	@/bin/echo -n "waiting for Kafka CRD..."
	@until oc get crd kafkas.kafka.strimzi.io >/dev/null 2>/dev/null; do \
	  /bin/echo -n "."; \
	  sleep 5; \
	done
	@echo "done"
	@echo "installing Kafka..."
	oc apply -n $(PROJ) -f $(BASE)/yaml/kafka.yaml

.PHONY: db
db:
	@oc new-project $(PROJ) || echo "$(PROJ) already exists"
	@echo "installing databases..."
	oc apply -n $(PROJ) -f $(BASE)/yaml/source-mssql.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/target-mssql.yaml

.PHONY: deploy-sqlpad
deploy-sqlpad:
	@oc new-project $(PROJ) || echo "$(PROJ) already exists"
	@echo "installing sqlpad..."
	oc apply -n $(PROJ) -f $(BASE)/yaml/sqlpad.yaml

.PHONY: debezium
debezium:
	@/bin/echo -n "waiting for Kafka pod to appear..."
	@until oc get -n $(PROJ) po/demo-kafka-0 2>/dev/null; do \
	  /bin/echo -n "."; \
	  sleep 5; \
	done
	@echo "done"
	@echo "waiting for Kafka to be ready..."
	oc wait -n $(PROJ) --for=condition=Ready --timeout=300s po/demo-kafka-0
	@echo "installing debezium..."
	oc apply -n $(PROJ) -f $(BASE)/yaml/debezium.yaml

.PHONY: sqlpad
sqlpad:
	@url="https://`oc get -n $(PROJ) route/sqlpad -o jsonpath='{.spec.host}'`"; \
	if [ "`uname -s`" = "Darwin" ]; then \
	  open "$$url"; \
	else \
	  echo "$$url"; \
	fi

.PHONY: clean
clean:
	oc project default
	@echo "deleting KafkaConnectors"
	oc delete -n $(PROJ) -f $(BASE)/yaml/target-connector.yaml
	oc delete -n $(PROJ) -f $(BASE)/yaml/source-connector.yaml
	@echo "deleting Debezium"
	oc delete -n $(PROJ) -f $(BASE)/yaml/debezium.yaml
	@echo "deleting Kafka"
	oc delete -n $(PROJ) -f $(BASE)/yaml/kafka.yaml
	@echo "deleting databases"
	oc delete -n $(PROJ) -f $(BASE)/yaml/target-mssql.yaml
	oc delete -n $(PROJ) -f $(BASE)/yaml/source-mssql.yaml
	@echo "deleting sqlpad"
	oc delete -n $(PROJ) -f $(BASE)/yaml/sqlpad.yaml
	@/bin/echo -n "waiting for all pods to disappear..."
	@while [ `oc get -n $(PROJ) po 2>/dev/null | wc -l` -gt 0 ]; do \
	  /bin/echo -n "."; \
	  sleep 5; \
	done
	@echo "done"
	oc delete project $(PROJ)
