require('dotenv').config();
const readline = require('readline');
const { AccessToken } = require('livekit-server-sdk');

const API_KEY = process.env.LIVEKIT_API_KEY || '';
const API_SECRET = process.env.LIVEKIT_API_SECRET || '';

if (!API_KEY || !API_SECRET) {
  console.error('❌ LIVEKIT_API_KEY or LIVEKIT_API_SECRET is missing in .env');
  process.exit(1);
}

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

async function generateToken(roomName, identity) {
  try {
    const at = new AccessToken(API_KEY, API_SECRET, { identity });

    // grant as plain object
    at.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });

    const token = await at.toJwt(); // await here
    console.log('\n✅ Generated LiveKit token:');
    console.log(token);
  } catch (err) {
    console.error('❌ Error creating LiveKit token:', err);
  } finally {
    rl.close();
  }
}

rl.question('Enter roomName: ', (roomName) => {
  rl.question('Enter identity (your user ID): ', (identity) => {
    generateToken(roomName, identity);
  });
});
