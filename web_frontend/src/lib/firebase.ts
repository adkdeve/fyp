// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyBfa3QaQ_xQ5fVpkPOsOzrwHtJeopd3fDU",
  authDomain: "fyp-backend-fa22.firebaseapp.com",
  projectId: "fyp-backend-fa22",
  storageBucket: "fyp-backend-fa22.firebasestorage.app",
  messagingSenderId: "1053439862866",
  appId: "1:1053439862866:web:86c27b9b610386f3f2978b"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firestore
export const db = getFirestore(app);

export default app;
