%livy.spark
 
 //The above magic instructs Zeppelin to use the Livy Scala interpreter

 // Create an RDD using the default Spark context, sc
 val tweetText = sc.textFile("adl://sparktwitterlakestore.azuredatalakestore.net/twitter/trump.csv")

//adl://<data_lake_store_name>.azuredatalakestore.net/<cluster_root>/HdiSamples/HdiSamples/SensorSampleData/hvac/HVAC.csv

 // Define a schema
 case class Tweet(createdAt: String, topic: String, sentiment: String, processedAt: String)

 // Map the values in the .csv file to the schema
 
 val tweets = tweetText.map(s => s.split('|')).map(
     s => Tweet(s(0), 
             s(1),
             s(2),
             s(3)
     )
 ).toDF()

 // Register as a temporary table called "TrumpTweets"
 tweets.registerTempTable("TrumpTweets")

 %sql
 // The above magic instructs Zeppelin to use the SQL interpreter

 // Below is an example sql query for the Tweets
 
select sentiment, count(*) as sentimentCount
from TrumpTweets
group by sentiment
order by sentimentCount desc