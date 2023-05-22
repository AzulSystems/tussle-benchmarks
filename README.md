# Tussle benchmarks & tools

This repository contains bunch of benchmark and tools projects.

## Kafka benchmark

Available as separate project:
https://github.com/AzulSystems/kafka-benchmark

## Cassandra benchmark

Project location: [cassandra-benchmark](cassandra-benchmark)

Build:

```
$ cd cassandra-benchmark/
$ mvn clean package -DskipTests
```

Run:

```
$ java -jar target/cassandra-benchmark-*.jar # test locally running Cassandra using default benchmark parameters (1 minute basic runner, etc.)
```

## HTTP client benchmark

[httpclient-benchmark-cli](httpclient-benchmark-cli)

## Springboot benchmark

[springboot-benchmark-app](springboot-benchmark-app)

## IO benchmark

[io-benchmark](io-benchmark)

## SQL benchmark

[sql-benchmark](sql-benchmark)
