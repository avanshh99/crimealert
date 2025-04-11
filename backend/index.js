const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(bodyParser.json());

const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const twilioPhone = process.env.TWILIO_PHONE_NUMBER;

const client = require('twilio')(accountSid, authToken);

app.post('/send-sms', async (req, res) => {
  const { to, message } = req.body;
  try {
    const msg = await client.messages.create({
      body: message,
      from: twilioPhone,
      to: to,
    });
    res.status(200).json({ success: true, sid: msg.sid });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.listen(5000, () => {
  console.log('Twilio backend running on http://localhost:5000');
});
