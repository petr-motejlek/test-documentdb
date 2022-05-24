const process = require('process');
const { MongoClient } = require('mongodb');

const ca = './rds-combined-ca-bundle.pem';
const url = `mongodb://${process.env.MONGO_USER}:${process.env.MONGO_PASSWORD}@${process.env.MONGO_HOST}:${process.env.MONGO_PORT}/?ssl=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false`;

(async () => {
  console.log("Connecting to:", url);

  client = await MongoClient.connect(
    url,
    {
      sslValidate: true,
      tlsAllowInvalidHostnames: true,
      sslCA: ca,
      useNewUrlParser: false,
      proxyHost: "127.0.0.1",
      proxyPort: process.env.MONGO_SOCKS_PORT
    }
  );
  console.log('Connected!');
  try {
    const db = client.db('testdb');
    const collection = db.collection('testcollection');

    await collection.insertOne(
      { time: new Date() }
    );

    console.log('Found: ', await collection.find({}).toArray());
  } finally {
    client.close();
  }
})().catch(console.error);
