// Replace the values below with the Web app config from Firebase Console.
// Keep this file aligned with FIREBASE_* build defines used by the Flutter app.
importScripts('https://www.gstatic.com/firebasejs/12.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'YOUR_FIREBASE_API_KEY',
  authDomain: 'YOUR_FIREBASE_PROJECT_ID.firebaseapp.com',
  projectId: 'YOUR_FIREBASE_PROJECT_ID',
  messagingSenderId: 'YOUR_FIREBASE_SENDER_ID',
  appId: 'YOUR_FIREBASE_WEB_APP_ID',
});

firebase.messaging();
