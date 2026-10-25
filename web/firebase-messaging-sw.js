// web/firebase-messaging-sw.js

const firebaseConfig = {
  apiKey: "AIzaSyDQMN0APdqFxVmFXErqh9vEJ7g_VtBE1Jw",
  authDomain: "jibon-sathi-matrimony-2a163.firebaseapp.com",
  projectId: "jibon-sathi-matrimony-2a163",
  storageBucket: "jibon-sathi-matrimony-2a163.firebasestorage.app",
  messagingSenderId: "726052229294",
  appId: "1:726052229294:web:7d65d7ad80b5d60099dd3f",
  measurementId: "G-VX57CRW9WZ"
};

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

// ✅ Service Worker দ্রুত activate করতে
self.addEventListener('install', () => { self.skipWaiting(); });
self.addEventListener('activate', (event) => { event.waitUntil(self.clients.claim()); });

// ✅ Background message handler
messaging.onBackgroundMessage((payload) => {
  console.log('[SW] Background message received:', payload);

  const data = payload.data || {};
  const type = data.type || '';

  let title = 'নতুন নোটিফিকেশন';
  let body = '';
  let icon = '/icons/Icon-192.png';
  let tag = 'general';

  if (type === 'call') {
    const isVideo = data.isVideoCall === 'true' || data.isVideoCall === true;
    title = isVideo ? '📹 Incoming Video Call' : '📞 Incoming Call';
    body = `${data.callerName || 'Someone'} is calling you...`;
    icon = data.callerPhoto || '/icons/Icon-192.png';
    tag = `call-${data.callId || Date.now()}`;
  } else if (type === 'message') {
    title = data.title || '💬 নতুন বার্তা';
    body = data.body || '';
    tag = `msg-${data.chatId || Date.now()}`;
  } else {
    title = data.title || 'নতুন নোটিফিকেশন';
    body = data.body || '';
  }

  return self.registration.showNotification(title, {
    body: body,
    icon: icon,
    badge: '/icons/Icon-192.png',
    tag: tag,
    data: data,
    requireInteraction: type === 'call', // ✅ call হলে user dismiss করা পর্যন্ত থাকবে
    vibrate: type === 'call' ? [500, 300, 500, 300, 500] : [200],
  });
});

// ✅ Notification click → অ্যাপ focus বা open + call হলে সরাসরি call screen
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const data = event.notification.data || {};
  const type = data.type || '';

  let url = '/';
  if (type === 'call' && data.callId) {
    url = `/?type=call&callId=${encodeURIComponent(data.callId)}`;
  } else if (type === 'message' && data.chatId) {
    url = `/?type=message&chatId=${encodeURIComponent(data.chatId)}`;
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          client.focus();
          client.postMessage({ type: type, data: data });
          return;
        }
      }
      return clients.openWindow(url);
    })
  );
});