// Give the service worker access to Firebase Messaging.
// Note that you can only use Firebase Messaging here. Other Firebase libraries
// are not available in the service worker.
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker by passing in
// your app's Firebase config object.
// https://firebase.google.com/docs/web/setup#config-object
firebase.initializeApp({
    apiKey: "AIzaSyAEXM6LO5S9Ar0kWa43KrfvRiDBnSfZwfo",
    authDomain: "ruchiserv-kitchen-e26d4.firebaseapp.com",
    projectId: "ruchiserv-kitchen-e26d4",
    storageBucket: "ruchiserv-kitchen-e26d4.firebasestorage.app",
    messagingSenderId: "742769773860",
    appId: "1:742769773860:web:85457eb60e8376f2aaf7b1",
    measurementId: "G-08PPTD6D45"
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages.
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);

    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/icons/Icon-192.png'
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});
