
// %livy.spark
 
 //The above magic instructs Zeppelin to use the Livy Scala interpreter

 // Create an RDD using the default Spark context, sc
 val tweetText = sc.textFile("adl://sparktwitterlakestore.azuredatalakestore.net/twitter/trump_1591835922_41c10d3c66cf46c1a33d05f817f8f9d1.csv")

//adl://<data_lake_store_name>.azuredatalakestore.net/<cluster_root>/HdiSamples/HdiSamples/SensorSampleData/hvac/HVAC.csv

 // Define a schema
 case class Tweet(createdAt: String, topic: String, sentiment: String, processedAt: String)

 // Map the values in the .csv file to the schema
 
 val tweets = tweetText.map(s => s.split("|")).map(
     s => Tweet(s(0), 
             s(1),
             s(2),
             s(3)
     )
 ).toDF()
 

// print out length of inner array to see if it's just 1 element- could be not matching the pipe character

 tweets.show()

 // Register as a temporary table called "TrumpTweets"
 tweets.registerTempTable("TrumpTweets")