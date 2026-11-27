// Replace the values below with the Web app config from Firebase Console.
// Keep this file aligned with FIREBASE_* build defines used by the Flutter app.
importScripts('https://www.gstatic.com/firebasejs/12.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyA_fNZAB0fGLFV9Arbk4iEklgB85NFOlEk',
  authDomain: 'demirturk-mobil-4954e.firebaseapp.com',
  projectId: 'demirturk-mobil-4954e',
  messagingSenderId: '833952865318',
  appId: '1:833952865318:web:7c0e25f433f20b2f715ae7',
});

firebase.messaging();
