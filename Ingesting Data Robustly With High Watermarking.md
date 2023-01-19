# Robust data ingestion with High-watermarking

Continuously copying data from its source to a new location is very common - backups, high availability, and analytics are just a few examples of why you would do so. But as data grows, making a full copy every time becomes impractical - copying terabytes of data requires time, compute, and networking resources, all of which increase the total cost of ownership of a solution. So, in most cases, it makes sense to load data incrementally - meaning, only what you need - each time you run the synchronization process.

In this article, we discuss a common technique for incremental data loading, called High-watermarking.

## What is High-watermarking?

High-watermarking (in the context of ETL) consists of a simple concept: using an auxiliary storage to keep track of the most recent data you've loaded, then starting each new copy from that point onwards. This has a couple of implications for the applicability of the technique:

1. There must be a field in the source data indicating how new each row or file is. We call this the watermark field, and it's commonly a "last updated" timestamp, or a sequential ID.
2. All changes to the data must be queryable by that watermark value - including deletions, if any.
3. There must be a way to merge those changes in the target data storage.

One common use case that conforms to all the requirements is "append-only" data, or data that is only ever inserted, and never updated or deleted. We'll use one such use case in the example below.

## A practical example: air quality sensor data

Imagine you have sensor data being generated every few seconds, and you need to move this data into a data lake for further analysis. This data can be queried by time intervals, and once generated, is never updated or deleted. This is a great candidate for incremental loading with high-watermarking!

First, let's look at the datasource. For this example, we'll use [OpenAQ](https://docs.openaq.org/docs), a free air quality sensor data repository. It currently requires no sign up or credentials, and is available through a REST API, so feel free to try it out as you read through the article.

### The datasource

Our datasource is specifically the [/v2/measurements](https://docs.openaq.org/reference/measurements_get_v2_measurements_get) endpoint. In short, you give it a locationID and a time range, and it outputs data collected at that location, between the time instants provided. Here's a sample:

```
{
  "meta": {
    "name": "openaq-api",
    "license": "CC BY 4.0d",
    "website": "api.openaq.org",
    "page": 1,
    "limit": 100,
    "found": 8599
  },
  "results": [
    {
      "locationId": 232441,
      "location": "1308 Richter Outdoors",
      "parameter": "um100",
      "value": 0,
      "date": {
        "utc": "2022-01-01T23:36:16+00:00",
        "local": "2022-01-01T15:36:16-08:00"
      },
      "unit": "particles/cm³",
      "coordinates": {
        "latitude": 49.89173,
        "longitude": -119.48874
      },
      "country": "CA",
      "city": null,
      "isMobile": false,
      "isAnalysis": null,
      "entity": "community",
      "sensorType": "low-cost sensor"
    },
        ...
```

So, given a locationID, how would you structure a data replication pipeline to continuously pull data from this API?

### The "easy" way

At this point, you may be thinking: "why don't we just run a Copy Data activity every, say, ten minutes, with the last ten minutes as a time range? That would make sure all data gets loaded, right?"

Well, in the real world, things are not so simple. Here are a few downsides to that strategy:

1. If new data gets generated in the time it takes for the pipeline to actually start up, it may get skipped over.
2. If the scheduled trigger is taken offline - either intentionally or due to an outage - you must manually re-sync the data copy. This often means running a full data load.
3. Different sensors may be added at different times, thus having entirely separate copy schedules. One sensor may be up-to-date, while others may be lagging behind - using a fixed watermark does not support this scenario.

### An improved strategy

Here's how you can work around these issues using high-watermarking.

1. Set up a metadata table with (minimally) two fields: a source identifier and a watermark - in this case, we'll use Azure Table Storage, which is available by default when you set up a storage account. It is also common to set this up in the source system when it is a relational database, such as SQL.
2. The first thing your pipeline should do is query that table for the source ID, and get the current watermark value. If it can't find the source ID, it means this is the first time it is being queried, so you will start loading from a pre-defined value. For timestamps, you may use the start date for your analysis.
3. After retrieving the high-watermark, the pipeline will determine the range for the next query - usually, it starts with the previous watermark, and it calculates the maximum date for this batch by adding a time interval. The time window itself depends on the use case - we will use one-day intervals.
4. Next, we actually copy the information to the data lake. Make sure to set up the sink dataset with the appropriate partitions - we will just use the device ID.
5. Finally, if the copy succeeds, we update the metadata table with the new watermark value - the end of the time range we just queried. 

Let's see that in practice!

Setting up the metadata table:


Reading the metadata table:
Setting variables for the time range:
Copying data:
Updating the metadata table:

Finally, we wrap everything up in an Until block, so that the process is repeated until we're close to the present date.

And that's it! No matter how often we run this pipeline, it will always copy data since the last time it was executed, and all the way until the present. Additionally, the metadata table provides quick insight into the synchronization status of each sensor.

## Wrap up

This was a quick introduction of high-watermarking as a technique for incremental data loading. It is a great tool for loading append-only data into a datalake, as well as other use-cases, as long as a few requirements are met. It makes data ingestion not only faster, but also cheaper, more reliable and flexible. 

## Resources

All the resources screenshotted above and more are available in [Github]()! You may use them as templates for setting up your own data ingestion pipelines using high-watermarking.

