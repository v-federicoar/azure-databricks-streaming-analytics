package com.microsoft.pnp

import com.datastax.spark.connector.cql.CassandraConnector
import org.apache.spark.sql.{ForeachWriter, Row}

class CassandraSinkForeach(con: CassandraConnector)
  extends ForeachWriter[Row] {

  // This class implements the interface ForeachWriter, which has methods that get called
  // whenever there is a sequence of rows generated as output
  def open(partitionId: Long, version: Long): Boolean = true

  def process(record: Row) = {
     try {
        println(s"Writing record to Cassandra: $record")
        con.withSessionDo(session => {
          val bound = session.prepare(
            s"""
              |insert into newyorktaxi.neighborhoodstats (neighborhood,window_end,number_of_rides,total_fare_amount,total_tip_amount,average_fare_amount,average_tip_amount)
              |       values(?, ?, ?, ?, ?, ?, ?)"""

          ).bind(
              record.getAs[String]("pickupNeighborhood"),
              record.getAs[java.sql.Timestamp]("end").toInstant,
              record.getAs[Long]("rideCount").asInstanceOf[AnyRef],
              record.getAs[Double]("totalFareAmount").asInstanceOf[AnyRef],
              record.getAs[Double]("totalTipAmount").asInstanceOf[AnyRef],
              record.getAs[Double]("averageFareAmount").asInstanceOf[AnyRef],
              record.getDouble(7).asInstanceOf[AnyRef]
          )

          session.execute(bound)
        })
      } catch {
          case e: Exception =>
            println(s"Error writing to Cassandra: ${e.getMessage}")
            e.printStackTrace()
            throw e // rethrow to ensure the error is logged and handled
      }
   }

  def close(errorOrNull: Throwable): Unit = {
    if (errorOrNull != null) {
        println(s"Error in CassandraSinkForeach: ${errorOrNull.getMessage}")
        errorOrNull.printStackTrace()
     }
  }
}
