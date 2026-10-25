const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

const db = admin.firestore();
const messaging = admin.messaging();

// ============================================================
// HELPER: User এর সব FCM token পান
// ============================================================
async function getUserTokens(uid) {
  try {
    const userDoc = await db.collection("users").doc(uid).get();
    return userDoc.data()?.fcmTokens || [];
  } catch (e) {
    logger.error("Failed to get tokens:", e);
    return [];
  }
}

// ============================================================
// HELPER: Invalid tokens cleanup
// ============================================================
async function cleanupInvalidTokens(uid, invalidTokens) {
  if (invalidTokens.length === 0) return;
  try {
    await db.collection("users").doc(uid).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
    });
  } catch (e) {
    logger.error("Cleanup failed:", e);
  }
}

// ============================================================
// HELPER: Push Notification পাঠান
// ============================================================
async function sendPushNotification(uid, title, body, data = {}) {
  const tokens = await getUserTokens(uid);
  if (tokens.length === 0) return;

  const message = {
    tokens: tokens,
    data: {
      ...data,
      title: title,
      body: body,
      type: data.type || "general",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      ttl: 60000,
      // ❌ এখানে কোনো notification ব্লক নেই। এটি Data-Only।
    },
    apns: {
      headers: { "apns-priority": "10", "apns-push-type": "background" },
      payload: { aps: { "content-available": 1 } },
    },
    // ✅ WEB PUSH — Service Worker-এ data পৌঁছাবে
    webpush: {
      headers: { Urgency: "high" },
      data: {
        ...data,
        title: title,
        body: body,
        type: data.type || "general",
      },
      fcmOptions: {
        link: "/",
      },
    },
  };

  try {
    const response = await messaging.sendEachForMulticast(message);
    logger.info(
      `Push: ${response.successCount}/${tokens.length} delivered to ${uid}`
    );

    // ✅ Invalid token cleanup
    if (response.failureCount > 0) {
      const invalidTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errCode = resp.error?.code;
          if (
            errCode === "messaging/invalid-registration-token" ||
            errCode === "messaging/registration-token-not-registered"
          ) {
            invalidTokens.push(tokens[idx]);
          }
        }
      });
      if (invalidTokens.length > 0) {
        await cleanupInvalidTokens(uid, invalidTokens);
      }
    }
  } catch (e) {
    logger.error("Push failed:", e);
  }
}

// ============================================================
// HELPER: In-App Notification Doc তৈরি
// ============================================================
async function createNotification(userId, notifData) {
  try {
    await db
      .collection("notifications")
      .doc(userId)
      .collection("items")
      .add({
        type: notifData.type || "general",
        title: notifData.title || "",
        body: notifData.body || "",
        fromUid: notifData.fromUid || "",
        fromName: notifData.fromName || "",
        fromPhotoUrl: notifData.fromPhotoUrl || "",
        data: notifData.data || {},
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    logger.info(`Notification doc created for ${userId}`);
  } catch (e) {
    logger.error("Notification doc failed:", e);
  }
}

// ============================================================
// 1. LIKE → Push + In-App Notification
// ============================================================
exports.onLikeCreated = onDocumentCreated(
  "likesReceived/{userId}/likedBy/{likerId}",
  async (event) => {
    const userId = event.params.userId;
    const likerId = event.params.likerId;

    try {
      const likerDoc = await db.collection("users").doc(likerId).get();
      const likerData = likerDoc.data() || {};
      const likerName = likerData.name || "Someone";
      const likerPhoto = likerData.photoUrl || "";

      await sendPushNotification(
        userId,
        "💕 New Like!",
        `${likerName} liked your profile`,
        { type: "like", uid: likerId, name: likerName }
      );

      await createNotification(userId, {
        type: "like",
        title: "💕 New Like!",
        body: `${likerName} liked your profile`,
        fromUid: likerId,
        fromName: likerName,
        fromPhotoUrl: likerPhoto,
        data: { uid: likerId, name: likerName },
      });
    } catch (e) {
      logger.error("Like handler failed:", e);
    }
  }
);

// ============================================================
// 2. MATCH → Push + In-App Notification
// ============================================================
exports.onMatchCreated = onDocumentCreated(
  "matches/{matchId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const users = data.users || [];
    const matchId = event.params.matchId;

    for (const uid of users) {
      try {
        const otherUid = users.find((u) => u !== uid);
        if (!otherUid) continue;

        const otherDoc = await db.collection("users").doc(otherUid).get();
        const otherData = otherDoc.data() || {};
        const otherName = otherData.name || "Someone";
        const otherPhoto = otherData.photoUrl || "";

        await sendPushNotification(
          uid,
          "🎉 It's a Match!",
          `You and ${otherName} liked each other!`,
          { type: "match", matchId, uid: otherUid, name: otherName }
        );

        await createNotification(uid, {
          type: "match",
          title: "🎉 It's a Match!",
          body: `You and ${otherName} liked each other!`,
          fromUid: otherUid,
          fromName: otherName,
          fromPhotoUrl: otherPhoto,
          data: { matchId, uid: otherUid, name: otherName },
        });
      } catch (e) {
        logger.error(`Match handler failed for ${uid}:`, e);
      }
    }
  }
);

// ============================================================
// 3. MESSAGE → Push + In-App Notification
// ============================================================
exports.onMessageCreated = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const senderId = data.senderId;
    const receiverId = data.receiverId;
    const text = data.text || data.message || "";

    if (!receiverId || !senderId) {
      logger.warn("Missing receiverId or senderId in message");
      return;
    }

    try {
      const senderDoc = await db.collection("users").doc(senderId).get();
      const senderData = senderDoc.data() || {};
      const senderName = senderData.name || "Someone";
      const preview = text.length > 100 ? text.substring(0, 100) + "..." : text;
      const chatId = event.params.chatId;

      await sendPushNotification(receiverId, `💬 ${senderName}`, preview, {
        type: "message",
        chatId: chatId,
        uid: senderId,
        name: senderName,
      });
    } catch (e) {
      logger.error("Message handler failed:", e);
    }
  }
);

// ============================================================
// 4. ✅ CALL CREATED — Data-Only Push (High Priority + Webpush)
// ============================================================
exports.onCallCreated = onDocumentCreated(
  {
    document: "calls/{callId}",
    region: "asia-south1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const callData = snap.data();
    const callId = event.params.callId;
    const receiverId = callData.receiverId;
    const callerId = callData.callerId || "";
    const callerName = callData.callerName || "Someone";
    const callerPhoto = callData.callerPhoto || "";
    const isVideoCall = callData.isVideoCall === true;
    const channelName = callData.channelName || "";

    if (!receiverId) return;

    try {
      const tokens = await getUserTokens(receiverId);
      if (tokens.length === 0) return;

      // ✅ Data-only message. High priority for Android.
      const message = {
        tokens: tokens,
        data: {
          type: "call",
          callId: callId,
          channelName: channelName,
          callerId: callerId,
          callerName: callerName,
          callerPhoto: callerPhoto,
          isVideoCall: isVideoCall ? "true" : "false",
        },
        android: {
          priority: "high", // ✅ HIGH PRIORITY MUST
          ttl: 60000, // ✅ 60 seconds timeout
          // ❌ NO notification block here (Data-only)
        },
        apns: {
          headers: {
            "apns-priority": "10",
            "apns-push-type": "background",
          },
          payload: {
            aps: { "content-available": 1 },
          },
        },
        // ✅ WEB PUSH — Service Worker এ কল ডেটা পৌঁছাবে
        webpush: {
          headers: { Urgency: "high" },
          data: {
            type: "call",
            callId: callId,
            channelName: channelName,
            callerId: callerId,
            callerName: callerName,
            callerPhoto: callerPhoto,
            isVideoCall: isVideoCall ? "true" : "false",
          },
          fcmOptions: {
            link: `/?type=call&callId=${callId}`,
          },
        },
      };

      const response = await messaging.sendEachForMulticast(message);
      logger.info(
        `📞 Call FCM: ${response.successCount}/${tokens.length} to ${receiverId}`
      );

      // ✅ Invalid token cleanup
      if (response.failureCount > 0) {
        const invalidTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const errCode = resp.error?.code;
            if (
              errCode === "messaging/invalid-registration-token" ||
              errCode === "messaging/registration-token-not-registered"
            ) {
              invalidTokens.push(tokens[idx]);
            }
          }
        });
        if (invalidTokens.length > 0) {
          await cleanupInvalidTokens(receiverId, invalidTokens);
        }
      }
    } catch (e) {
      logger.error("Call FCM handler failed:", e);
    }
  }
);

// ============================================================
// 5. CALL STATUS CHANGED → Notify Caller
// ============================================================
exports.onCallStatusChanged = onDocumentUpdated(
  {
    document: "calls/{callId}",
    region: "asia-south1",
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) return;
    if (before.status === after.status) return;

    const callId = event.params.callId;
    const status = after.status;
    const callerId = after.callerId;
    const receiverName = after.receiverName || "User";

    // শুধু এই status-এ caller-কে notify করবো
    const notifyStatuses = ["accepted", "rejected", "ended", "missed"];
    if (!notifyStatuses.includes(status)) return;

    try {
      let title = "";
      let body = "";

      switch (status) {
        case "accepted":
          title = "✅ Call Accepted";
          body = `${receiverName} accepted your call`;
          break;
        case "rejected":
          title = "❌ Call Declined";
          body = `${receiverName} declined your call`;
          break;
        case "ended":
          title = "📴 Call Ended";
          body = `Call with ${receiverName} ended`;
          break;
        case "missed":
          title = "📭 Missed Call";
          body = `${receiverName} missed your call`;
          break;
      }

      await sendPushNotification(callerId, title, body, {
        type: "call_status",
        callId: callId,
        status: status,
      });
    } catch (e) {
      logger.error("Call status FCM handler failed:", e);
    }
  }
);

// ============================================================
// AGORA TOKEN GENERATOR
// ============================================================
const { RtcTokenBuilder, RtcRole } = require("agora-access-token");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const AGORA_APP_ID = defineSecret("AGORA_APP_ID");
const AGORA_CERTIFICATE = defineSecret("AGORA_CERTIFICATE");

exports.generateAgoraToken = onCall(
  {
    secrets: [AGORA_APP_ID, AGORA_CERTIFICATE],
    region: "asia-south1",
  },
  async (request) => {
    const { channelName, uid } = request.data;

    if (!channelName || !uid) {
      throw new HttpsError(
        "invalid-argument",
        "channelName and uid are required"
      );
    }

    const appId = AGORA_APP_ID.value();
    const appCertificate = AGORA_CERTIFICATE.value();

    const expirationTimeInSeconds = 3600;
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      parseInt(uid),
      RtcRole.PUBLISHER,
      privilegeExpiredTs
    );

    console.log(`✅ Token generated for channel: ${channelName}, uid: ${uid}`);

    return {
      token: token,
      appId: appId,
      channelName: channelName,
      uid: parseInt(uid),
      expiresAt: privilegeExpiredTs,
    };
  }
);