# Debezium MS SQL Server Demo

This demo shows how you replicate from one MS SQL Server to another MS SQL Server.

## Cluster Setup

01. Provision a 4.15 Red Hat OpenShift Container Platform Cluster (AWS)

01. Install the Streams for Apache Kafka operator

01. Create the `demo` project

		oc new-project demo
		
01. Deploy the Kafka cluster

		oc apply -f yaml/kafka.yaml

01. Wait for the Kafka pods to come up, then deploy Debezium (we do this ahead of time because we need to build an image at deployment time, and this could take a few minutes)

		oc apply -f yaml/debezium.yaml

01. Deploy the source database

		oc apply -f yaml/source-mssql.yaml

01. Deploy the target database

		oc apply -f yaml/target-mssql.yaml


## Demo

Before you start the demo, ensure that you have logged in using `oc login` and that you are in the `demo` project.

01. Examine the `customers` table in the source database

		oc rsh sts/source-mssql \
		  /opt/mssql-tools18/bin/sqlcmd \
		    -No \
		    -S localhost \
		    -U sa \
		    -P Password! \
		    -d InternationalDB \
		    -Q "select * from dbo.Customers"

	You should see 3 rows in the table

01. Query the target database - notice how the `customers` table does not exist

		oc rsh deploy/target-mssql \
		  /opt/mssql-tools18/bin/sqlcmd \
		    -No \
		    -S localhost \
		    -U sa \
		    -P Password! \
		    -d InternationalDB \
		    -Q "select name from sys.tables"

01. Deploy the source connector - this syncs data from the source database to Kafka

		cat yaml/debezium-connector.yaml

		oc apply -f yaml/debezium-connector.yaml

01. **Optional**: If you want to look at the Debezium logs

		oc logs -f debezium-kafka-connect-cluster-connect-0

01. List the topics in Kafka

		oc rsh demo-kafka-0 \
		  /opt/kafka/bin/kafka-topics.sh \
		    --bootstrap-server demo-kafka-bootstrap:9092 \
		    --list

	You should see a topic named `debezium.InternationalDB.dbo.Customers`
	
01. Examine the messages in that topic

		oc rsh demo-kafka-0 \
		  /opt/kafka/bin/kafka-console-consumer.sh \
		    --bootstrap-server demo-kafka-bootstrap:9092 \
		    --topic debezium.InternationalDB.dbo.Customers \
		    --from-beginning

	Ctrl-C to exit the consumer

01. Deploy the sink connector - this syncs data from Kafka to the target database

		cat yaml/jdbc-connector.yaml

		oc apply -f yaml/jdbc-connector.yaml

01. Query the target database

		oc rsh deploy/target-mssql \
		  /opt/mssql-tools18/bin/sqlcmd \
		    -No \
		    -S localhost \
		    -U sa \
		    -P Password! \
		    -d InternationalDB \
		    -Q "select name from sys.tables"

	Notice how the `Customers` table is now created in the target database

01. Query the `Customers` table in the target database

		oc rsh deploy/target-mssql \
		  /opt/mssql-tools18/bin/sqlcmd \
		    -No \
		    -S localhost \
		    -U sa \
		    -P Password! \
		    -d InternationalDB \
		    -Q "select * from dbo.Customers"

	The `Customers` table should contain 3 rows

01. Insert a new row into the `Customers` table in the source database

		oc rsh sts/source-mssql \
		  /opt/mssql-tools18/bin/sqlcmd \
		    -No \
		    -S localhost \
		    -U sa \
		    -P Password! \
		    -d InternationalDB \
		    -Q "insert into dbo.Customers values
		    (1004,
		    'Laurie',
		    'York',
		    'laurie@york.com')"

01. Query the `Customers` table in the target database

		oc rsh deploy/target-mssql \
		  /opt/mssql-tools18/bin/sqlcmd \
		    -No \
		    -S localhost \
		    -U sa \
		    -P Password! \
		    -d InternationalDB \
		    -Q "select * from dbo.Customers"

	The `Customers` table should contain 4 rows

01. Add a new column to the `Customers` table in the source database

		oc rsh sts/source-mssql \
		  /opt/mssql-tools18/bin/sqlcmd \
		    -No \
		    -S localhost \
		    -U sa \
		    -P Password! \
		    -d InternationalDB \
		    -Q "alter table dbo.Customers
		    add phone varchar(15)"

01. Notify CDC of the schema change - this is a [limitation of CDC on SQL Server](https://debezium.io/documentation/reference/stable/connectors/sqlserver.html#sqlserver-schema-evolution)

		oc rsh sts/source-mssql \
		  /opt/mssql-tools18/bin/sqlcmd \
		    -No \
		    -S localhost \
		    -U sa \
		    -P Password! \
		    -d InternationalDB \
		    -Q "EXEC sys.sp_cdc_enable_table
		    @source_schema = 'dbo',
		    @source_name = 'Customers',
		    @role_name = NULL,
		    @supports_net_changes = 0,
		    @capture_instance = 'dbo_customers_v2'"

01. Update a record with a new column value

		oc rsh sts/source-mssql \
		  /opt/mssql-tools18/bin/sqlcmd \
		    -No \
		    -S localhost \
		    -U sa \
		    -P Password! \
		    -d InternationalDB \
		    -Q "update dbo.Customers
		    set phone='12345678'
		    where id=1004"

01. Query the `Customers` table in the target database

		oc rsh deploy/target-mssql \
		  /opt/mssql-tools18/bin/sqlcmd \
		    -No \
		    -S localhost \
		    -U sa \
		    -P Password! \
		    -d InternationalDB \
		    -Q "select * from dbo.Customers"

	The `Customers` table should contain a `phone` column


## Troubleshooting

*   Check the status of the SQL Server Agent in the source database

		oc rsh sts/source-mssql \
		  /opt/mssql-tools18/bin/sqlcmd \
		    -No \
		    -S localhost \
		    -U sa \
		    -P Password! \
		    -d InternationalDB \
		    -Q "SELECT dss.[status], dss.[status_desc]
		    FROM   sys.dm_server_services dss
		    WHERE  dss.[servicename]
		    LIKE N'SQL Server Agent (%'"

