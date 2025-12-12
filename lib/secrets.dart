// lib/secrets.dart
/// 🔐 Put your real API keys here.

// 2Factor.in OTP Service
const String twoFactorApiKey = '383edc87-bd32-11f0-bdde-0200cd936042';

// SendGrid (Optional - for Email notifications)
const String sendgridApiKey = 'YOUR_SENDGRID_API_KEY'; // Get from sendgrid.com

// Meta WhatsApp Business Platform API (Official WhatsApp Integration)
const String metaWhatsAppToken = 'YOUR_META_ACCESS_TOKEN'; // Get from Meta Developer Portal
const String metaWhatsAppPhoneId = 'YOUR_PHONE_NUMBER_ID'; // Get from WhatsApp Business API Setup

// Twilio (Alternative - for WhatsApp notifications via Twilio)
const String twilioAccountSid = 'YOUR_TWILIO_ACCOUNT_SID';
const String twilioAuthToken = 'YOUR_TWILIO_AUTH_TOKEN';
const String twilioWhatsAppNumber = 'whatsapp:+14155238886'; // Twilio sandbox number

// Razorpay (Optional - for Payments)
const String razorpayKeyId = 'YOUR_RAZORPAY_KEY_ID';
const String razorpayKeySecret = 'YOUR_RAZORPAY_KEY_SECRET';
