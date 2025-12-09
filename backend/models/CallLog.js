const mongoose = require('mongoose');
const CallLogSchema = new mongoose.Schema({
  roomId: { type: String, required: true, index: true },
  participants: [{ userId: String, socketId: String }],
  startedAt: { type: Date, default: Date.now },
  endedAt: { type: Date },
  type: { type: String, enum: ['audio','video','unknown'], default: 'unknown' },
  metadata: { type: Object }
});
module.exports = mongoose.model('CallLog', CallLogSchema);
