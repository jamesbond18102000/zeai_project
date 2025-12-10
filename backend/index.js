const path = require("path");
//require("dotenv").config({ path: path.resolve(__dirname, "../.env") });
require("dotenv").config();

const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const mongoose = require("mongoose");
const cors = require("cors");
const { AccessToken } = require("livekit-server-sdk"); // LiveKit token

// models & routes (keep your existing requires)
const Employee = require("./models/employee");
const LeaveBalance = require("./models/leaveBalance");
const Payslip = require("./schema/payslip");

const employeeRoutes = require("./routes/employee");
const leaveRoutes = require("./routes/leave");
const profileRoutes = require("./routes/profile_route");
const todoRoutes = require("./routes/todo");
const attendanceRoutes = require("./routes/attendance");
const performanceRoutes = require("./routes/performance");
const reviewRiver = require("./routes/adminperformance");
const reviewscreen = require("./routes/reviewRoutes");
const reviewDecisionRoutes = require("./routes/performanceDecision");
const notificationRoutes = require("./routes/notifications");
const requestsRoutes = require("./routes/changeRequests");
const uploadRoutes = require("./routes/upload");
const payslipRoutes = require("./routes/payslip");

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 5000;
const MONGO_URI = process.env.MONGO_URI || "";

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const corsOptions = {
  origin: [
    "https://hrm15.netlify.app",
    "https://zeai-project.onrender.com",
    "http://localhost:5000",
  ],
  methods: ["GET", "POST", "PUT", "DELETE"],
  credentials: true,
};
app.use(cors(corsOptions));

// Simple request logger
app.use((req, res, next) => {
  console.log(`➡️ ${req.method} ${req.originalUrl}`);
  next();
});

// ---------- Socket.IO ---------- //
const io = new Server(server, { cors: corsOptions });

// Keep mapping userId -> socketId (or multiple sockets per user)
const userSockets = new Map(); // userId -> Set(socketId)

function addUserSocket(userId, socketId) {
  if (!userId) return;
  if (!userSockets.has(userId)) userSockets.set(userId, new Set());
  userSockets.get(userId).add(socketId);
  console.log(`✅ Registered mapping: ${userId} -> ${socketId}`);
}

function removeUserSocket(socketId) {
  for (const [userId, sset] of userSockets.entries()) {
    if (sset.has(socketId)) {
      sset.delete(socketId);
      if (sset.size === 0) userSockets.delete(userId);
      console.log(`❌ Removed mapping: ${userId} -> ${socketId}`);
      return;
    }
  }
}

function emitToUser(userId, event, payload) {
  const sockets = userSockets.get(userId);
  if (!sockets || sockets.size === 0) {
    console.log(`⚠️ emitToUser: user ${userId} offline (no socket)`);
    return false;
  }
  for (const sId of sockets) {
    io.to(sId).emit(event, payload);
  }
  return true;
}

io.on("connection", (socket) => {
  console.log(`🔌 Socket connected: ${socket.id}`);

  // Accept register from client
  socket.on("register", (userId) => {
    // The client might send an object like { userId: '...' } or just the string.
    // This handles both cases to ensure we always get a string ID.
    const id = typeof userId === 'object' && userId !== null ? userId.userId : userId;
    if (!id) return;
    addUserSocket(String(id), socket.id);
  });

  socket.on("disconnect", () => {
    console.log(`🔌 Socket disconnected: ${socket.id}`);
    removeUserSocket(socket.id);
  });

  socket.on("call-user", (data) => {
    console.log(
      `📞 call-user event: from=${data.fromUserId || 'undefined'} to=${data.toUserId} room=${data.roomId} video=${data.isVideo} callerName=${data.callerName || 'Unknown'}`
    );

    const sent = emitToUser(data.toUserId, "incoming-call", {
      fromUserId: data.fromUserId,
      callerName: data.callerName || data.fromUserId || "Unknown",
      roomId: data.roomId,
      isVideo: data.isVideo,
    });

    if (sent) {
      console.log(`✅ Incoming call forwarded to ${data.toUserId}`);
    } else {
      console.log(`❌ Target user ${data.toUserId} not connected`);
      // Optionally notify caller with 'user-offline'
      socket.emit("user-offline", { toUserId: data.toUserId });
    }
  });

  // ✅ ADD THIS: Listen for new messages from a client
  socket.on("send-message", (data) => {
    const { toUserId, message, fromUserId } = data || {};
    if (!toUserId || !message || !fromUserId) {
      console.log("⚠️  Invalid message payload received:", data);
      return;
    }

    console.log(`✉️  Relaying message from ${fromUserId} to ${toUserId}`);

    // Forward the message to the recipient
    const sent = emitToUser(toUserId, "new-message", {
      fromUserId: fromUserId,
      message: message,
    });

    if (!sent) {
      console.log(`❌ Could not deliver message to offline user ${toUserId}`);
    }
  });
  // optional signaling events
  socket.on("accept-call", (payload) => {
    console.log(`✅ accept-call from ${socket.id} payload: ${JSON.stringify(payload)}`);
    const { toSocketId, roomId } = payload || {};
    if (toSocketId) io.to(toSocketId).emit("call-accepted", { fromSocket: socket.id, roomId });
  });

  socket.on("reject-call", (payload) => {
    console.log(`❌ reject-call from ${socket.id} payload: ${JSON.stringify(payload)}`);
    const { toSocketId } = payload || {};
    if (toSocketId) io.to(toSocketId).emit("call-rejected", { fromSocket: socket.id });
  });

  // raw WebRTC forwarding events...
  socket.on("offer", ({ toSocketId, offer }) => {
    io.to(toSocketId).emit("offer", { fromSocket: socket.id, offer });
  });
  socket.on("answer", ({ toSocketId, answer }) => {
    io.to(toSocketId).emit("answer", { fromSocket: socket.id, answer });
  });
  socket.on("ice-candidate", ({ toSocketId, candidate }) => {
    io.to(toSocketId).emit("ice-candidate", { fromSocket: socket.id, candidate });
  });
});

// Middleware to extract user identity from headers
const userAuthMiddleware = (req, res, next) => {
  const userId = req.headers['x-user-id'];
  if (userId) {
    req.userId = userId; // Attach userId to the request object
    console.log(`[Auth] Request by user: ${userId}`);
  } else {
    console.log(`[Auth] Anonymous request for ${req.method} ${req.path}`);
  }
  next();
};

// ✅ CRITICAL: Use middleware BEFORE the routes that need it.
app.use(userAuthMiddleware);

// Static files & routes
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// ✅ CRITICAL: Define specific routes like this BEFORE more general ones.
app.get("/api/get-employee-name/:employeeId", async (req, res) => {
  try {
    const employee = await Employee.findOne({ employeeId: req.params.employeeId.trim() });
    if (!employee) {
      console.log(`⚠️ Employee not found for ID: ${req.params.employeeId}`);
      return res.status(404).json({ message: "Employee not found" });
    }
    res.status(200).json({
      employeeName: employee.employeeName,
      position: employee.position,
    });
  } catch (error) {
    console.error("❌ Get Employee Name Error:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

app.use("/api", employeeRoutes);
app.use("/apply", leaveRoutes);
app.use("/profile", profileRoutes);
app.use("/todo_planner", todoRoutes);
app.use("/attendance", attendanceRoutes);
app.use("/perform", performanceRoutes);
app.use("/reviews", reviewRiver);
app.use("/reports", reviewscreen);
app.use("/review-decision", reviewDecisionRoutes);
app.use("/api", notificationRoutes);
app.use("/api", requestsRoutes);
app.use("/upload", uploadRoutes);
app.use("/payslip", payslipRoutes);

// LiveKit token endpoint (same logic you had)
app.post("/api/get-livekit-token", async (req, res) => {
  const { roomName, identity } = req.body || {};
  if (!roomName || !identity) {
    console.log("⚠️ LiveKit token request missing roomName or identity");
    return res.status(400).json({ error: "roomName and identity are required" });
  }
  const API_KEY = (process.env.LIVEKIT_API_KEY || "").trim();
  const API_SECRET = (process.env.LIVEKIT_API_SECRET || "").trim();
  if (!API_KEY || !API_SECRET) {
    console.log("❌ LiveKit API key or secret missing in backend!");
    return res.status(500).json({ error: "LiveKit API key/secret not set" });
  }
  try {
    const at = new AccessToken(API_KEY, API_SECRET, { identity: String(identity) });
    at.addGrant({
      roomJoin: true,
      room: String(roomName),
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });
    const token = await at.toJwt();
    console.log(`✅ LiveKit token generated for ${identity} in room ${roomName}`);
    res.status(200).json({ token });
  } catch (error) {
    console.log("❌ LiveKit token generation error:", error);
    res.status(500).json({ error: "Error creating LiveKit token", details: error.message });
  }
});

// New: endpoint to accept lightweight client-side logs so they appear in Render logs
app.post("/api/log-client-event", (req, res) => {
  try {
    const { level = "info", message, meta } = req.body || {};
    console.log(`[CLIENT-LOG] [${level.toUpperCase()}] ${message} ${meta ? JSON.stringify(meta) : ""}`);
    res.status(200).json({ ok: true });
  } catch (err) {
    console.log("❌ Error in /api/log-client-event:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.get("/api/debug-livekit", (req, res) => {
  res.json({
    api_key_present: Boolean(process.env.LIVEKIT_API_KEY),
    api_secret_present: Boolean(process.env.LIVEKIT_API_SECRET),
    livekit_url: process.env.LIVEKIT_URL || null,
  });
});

app.get("/", (req, res) => res.send("✅ HRM Backend Running"));

mongoose
  .connect(MONGO_URI)
  .then(() => {
    console.log("✅ MongoDB Connected");
    server.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
  })
  .catch((err) => {
    console.log("❌ MongoDB connection error:", err);
    server.listen(PORT, () => console.log(`🚀 Server running on port ${PORT} (DB not connected)`));
  });
