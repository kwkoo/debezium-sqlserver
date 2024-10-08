# Debezium MS SQL Server Demo

This demo shows how you replicate from one MS SQL Server to another MS SQL Server.

## Cluster Setup

01. Provision a 4.15 Red Hat OpenShift Container Platform Cluster (AWS)

01. Login to the cluster using `oc login`

01. Install required components

		make deploy
	
	This will:
	
	*   Install the Streams for Apache Kafka operator
	*   Deploy the source and target MS SQL Server databases
	*   Deploy the Kafka cluster
	*   Deploy Kafdrop
	*   Deploy Debezium


## Demo

Before you start the demo

*   Ensure that you have logged in using `oc login` and that you are in the `demo` project.

*    Open a web browser to the sqlpad interface

		make sqlpad

*   Login to sqlpad as `admin` / `admin`

*    Open a web browser to the kafdrop interface

		make kafdrop

*   **Optional**: If you want to look at the Debezium logs

		oc logs -f debezium-kafka-connect-cluster-connect-0

---

01. Examine the `customers` table in the source database

	*   In sqlpad, select `Queries` / `Customers in Source` / `Run`

		You should see 3 rows in the table

01. Query the target database - notice how the `customers` table does not exist

	*   In sqlpad, select `Target Database` in the databases dropdown box

	*   Show that the `dbo.Customers` table does not exist in the left pane; you may also want to run the following query

			SELECT * FROM SYS.TABLES

01. Deploy the source connector - this syncs data from the source database to Kafka

		cat yaml/source-connector.yaml

		oc apply -f yaml/source-connector.yaml

01. List the topics in Kafka

	*   Switch over to the kafdrop browser window and refresh the page
	*   You should see a topic named `debezium.InternationalDB.dbo.Customers`
	
01. Examine the messages in that topic by selecting `debezium.InternationalDB.dbo.Customers` / `View Messages` / `View Messages`

01. Deploy the sink connector - this syncs data from Kafka to the target database

		cat yaml/target-connector.yaml

		oc apply -f yaml/target-connector.yaml

01. Query the target database

	*   In sqlpad, select `Queries` / `Customers in Target` / `Run`

		The `Customers` table should contain 3 rows

01. Insert a new row into the `Customers` table in the source database

	*   In sqlpad, select `Queries` / `Insert New Customer` / `Run`

01. Query the `Customers` table in the target database

	*   In sqlpad, select `Target Database` in the databases dropdown box

	*   Show that the `dbo.Customers` table appears in the left pane

	*   Select `Queries` / `Customers in Target` / `Run`

		The `Customers` table should contain 4 rows

01. Add a new column to the `Customers` table in the source database

	*   In sqlpad, select `Queries` / `Add New Column` / `Run`
	*   Select `Source Database` / `Refresh schema` (the circular icon with an arrow) - the Customers table should now include a `phone` column

01. Notify CDC of the schema change - this is a [limitation of CDC on SQL Server](https://debezium.io/documentation/reference/stable/connectors/sqlserver.html#sqlserver-schema-evolution)

	*   In sqlpad, select `Queries` / `Change Capture Instance` / `Run`

01. Update a record with a new column value

	*   In sqlpad, select `Queries` / `Update phone` / `Run`

01. Query the `Customers` table in the target database

	*   In sqlpad, select `Queries` / `Customers in Target` / `Run`

		The `Customers` table should contain a `phone` column


## Cleaning up after the demo

*   Delete everything with

		make clean


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

*   The source database was converted from a `Deployment` to a `StatefulSet` because pods belonging to a `Deployment` have very long hostnames, and the MS SQL Server Agent will not run when the hostname exceeds a certain length


## Command Line Queries

*   Query the source database

		oc rsh sts/source-mssql \
		  /opt/mssql-tools18/bin/sqlcmd \
		    -No \
		    -S localhost \
		    -U sa \
		    -P Password! \
		    -d InternationalDB \
		    -Q "select * from dbo.Customers"

*   List Kafka topics

		oc rsh demo-kafka-0 \
		  /opt/kafka/bin/kafka-topics.sh \
		    --bootstrap-server demo-kafka-bootstrap:9092 \
		    --list

*   Consume Kafka topic

		oc rsh demo-kafka-0 \
		  /opt/kafka/bin/kafka-console-consumer.sh \
		    --bootstrap-server demo-kafka-bootstrap:9092 \
		    --topic debezium.InternationalDB.dbo.Customers \
		    --from-beginning

*   Examine Debezium logs

		oc logs -f debezium-kafka-connect-cluster-connect-0
