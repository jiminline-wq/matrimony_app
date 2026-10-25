// web/firebase-messaging-sw.js

// আপনার Firebase প্রজেক্টের কনফিগারেশন এখানে বসান
// Firebase Console -> Project Settings -> General -> Your apps -> Web app -> Config
const firebaseConfig = {
  apiKey: "AIzaSyDQMN0APdqFxVmFXErqh9vEJ7g_VtBE1Jw",
  authDomain: "jibon-sathi-matrimony-2a163.firebaseapp.com",
  projectId: "jibon-sathi-matrimony-2a163",
  storageBucket: "jibon-sathi-matrimony-2a163.firebasestorage.app",
  messagingSenderId: "726052229294",
  appId: "1:726052229294:web:7d65d7ad80b5d60099dd3f",
  measurementId: "G-VX57CRW9WZ"
};

// Firebase SDK ইমপোর্ট করুন (compat ভার্সন ব্যবহার করা হচ্ছে)
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Firebase ইনিশিয়ালাইজ করুন
firebase.initializeApp(firebaseConfig);

// Messaging সার্ভিস ওয়ার্কার ইনিশিয়ালাইজ করুন
const messaging = firebase.messaging();

// ব্যাকগ্রাউন্ড নোটিফিকেশন হ্যান্ডলার (ঐচ্ছিক কিন্তু সুপারিশকৃত)
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  // এখানে আপনি নোটিফিকেশন কাস্টমাইজ করতে পারেন
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png' // আপনার অ্যাপের আইকনের পাথ
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});