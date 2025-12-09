
const CallLog = require('../models/CallLog'); // optional for logging calls

module.exports = function attachSignaling(server, app, opts = {}) {
  const io = require('socket.io')(server, {
    cors: { origin: opts.origin || '*', methods: ['GET', 'POST'] }
  });

  // Maps for tracking users and their connected sockets
  const socketIdToUser = new Map(); // socketId => userId
  const userToSockets = new Map();  // userId => Set of socketIds

  function addUserSocket(userId, socketId) {
    socketIdToUser.set(socketId, userId);
    if (!userToSockets.has(userId)) userToSockets.set(userId, new Set());
    userToSockets.get(userId).add(socketId);
  }

  function removeSocket(socketId) {
    const userId = socketIdToUser.get(socketId);
    if (!userId) return;
    socketIdToUser.delete(socketId);
    const set = userToSockets.get(userId);
    if (set) {
      set.delete(socketId);
      if (set.size === 0) userToSockets.delete(userId);
    }
  }

  function emitToUser(userId, event, payload) {
    const sockets = userToSockets.get(userId);
    if (!sockets || sockets.size === 0) {
      console.log(`⚠️ Tried emitting "${event}" but user ${userId} is offline`);
      return false;
    }
    for (const sId of sockets) {
      io.to(sId).emit(event, payload);
    }
    return true;
  }

  io.on('connection', (socket) => {
    console.log(`🔗 User connected: ${socket.id}`);

    // Register user
    socket.on('register', ({ userId }) => {
      if (!userId) return;
      addUserSocket(userId, socket.id);
      socket.emit('registered', { socketId: socket.id });
      console.log(`✅ Registered user: ${userId} => ${socket.id}`);
    });

    // Initiate call
    socket.on('call-user', ({ toUserId, roomId, callType }) => {
      const fromUserId = socketIdToUser.get(socket.id);
      console.log(`📞 Call attempt from ${fromUserId} to ${toUserId}, room: ${roomId}, type: ${callType}`);
      
      const sent = emitToUser(toUserId, "incoming-call", {
        fromUser: fromUserId,
        fromSocket: socket.id,
        roomId,
        callType
      });

      if (sent) {
        console.log(`✅ Incoming call sent to ${toUserId}`);
      } else {
        socket.emit('user-offline', { toUserId });
        console.log(`❌ User ${toUserId} is offline`);
      }
    });

    // Accept call
    socket.on('accept-call', ({ toSocketId, roomId }) => {
      console.log(`✅ Call accepted by ${socket.id} for ${toSocketId}, room: ${roomId}`);
      io.to(toSocketId).emit('call-accepted', { fromSocket: socket.id, roomId });
    });

    // Reject call
    socket.on('reject-call', ({ toSocketId }) => {
      console.log(`❌ Call rejected by ${socket.id} for ${toSocketId}`);
      io.to(toSocketId).emit('call-rejected', { fromSocket: socket.id });
    });

    // WebRTC offer
    socket.on("offer", ({ toSocketId, offer }) => {
      console.log(`💡 Offer from ${socket.id} -> ${toSocketId}`);
      io.to(toSocketId).emit("offer", { fromSocket: socket.id, offer });
    });

    // WebRTC answer
    socket.on("answer", ({ toSocketId, answer }) => {
      console.log(`💡 Answer from ${socket.id} -> ${toSocketId}`);
      io.to(toSocketId).emit("answer", { fromSocket: socket.id, answer });
    });

    // ICE candidate exchange
    socket.on("ice-candidate", ({ toSocketId, candidate }) => {
      io.to(toSocketId).emit("ice-candidate", { fromSocket: socket.id, candidate });
    });

    // End call
    socket.on("end_call", ({ toSocketId }) => {
      if (toSocketId) {
        io.to(toSocketId).emit("call-ended", { fromSocket: socket.id });
        console.log(`📴 Call ended by ${socket.id} for ${toSocketId}`);
      }
    });

    // Disconnect
    socket.on("disconnect", () => {
      console.log(`❌ User disconnected: ${socket.id}`);
      removeSocket(socket.id);
    });
  });

  return io;
};
