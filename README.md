# DailyKit — All-in-One Daily Management App

**DailyKit** is a full-stack production-grade daily productivity application built with **Flutter (Material 3)**, a secure **Node.js + Express** REST API, and **MySQL 8**.

---

## 🏗️ Architecture Overview

```text
┌───────────────────────────────────────────────┐
│          Flutter Android Client (App)         │
│  - Material 3 (Light & Dark Theme)            │
│  - State Management: Provider                 │
│  - Networking: Dio with JWT Interceptor       │
│  - Secure Storage: flutter_secure_storage     │
│  - Offline Queue: SharedPreferences          │
│  - Charts: fl_chart                           │
│  - Notifications: flutter_local_notifications │
└───────────────────────┬───────────────────────┘
                        │ HTTP / JSON
                        ▼
┌───────────────────────────────────────────────┐
│          REST API (Node.js + Express)         │
│  - Parameterized Queries (mysql2)             │
│  - JWT Authentication + bcrypt                │
│  - Rate Limiting (express-rate-limit)         │
│  - Strict User-Level Data Isolation           │
└───────────────────────┬───────────────────────┘
                        │ SQL (Port 3306)
                        ▼
┌───────────────────────────────────────────────┐
│               MySQL 8.0 Database              │
│  - InnoDB, utf8mb4                            │
│  - Foreign Keys with CASCADE / RESTRICT       │
│  - B-Tree and Compound Indexes                │
└───────────────────────────────────────────────┘
```

> **Security Note:** The Flutter mobile application never connects directly to MySQL. All operations are authenticated via JWT Bearer tokens and processed through the REST API.

---

## 📦 Project Structure

```text
Mobile App/
├── README.md                              # Complete run & architecture guide
│
├── backend/                               # Node.js + Express API
│   ├── database/
│   │   ├── schema.sql                     # Complete MySQL 8 DDL with FKs & indexes
│   │   └── seed.sql                       # Default categories + demo user & records
│   ├── src/
│   │   ├── config/db.js                   # mysql2 connection pool
│   │   ├── controllers/
│   │   │   ├── authController.js          # Register, Login (bcrypt + JWT), Profile
│   │   │   ├── habitController.js         # CRUD, one-tap check-in, streak calculation
│   │   │   ├── expenseController.js       # CRUD, quick-add, reports & category charts
│   │   │   └── itemController.js          # Where I Kept It: search, history, move
│   │   ├── middlewares/
│   │   │   ├── authMiddleware.js          # JWT verification & user attachment
│   │   │   ├── rateLimiter.js             # Rate limiter for auth & API
│   │   │   └── errorHandler.js            # Central error handler
│   │   ├── routes/
│   │   │   ├── authRoutes.js
│   │   │   ├── habitRoutes.js
│   │   │   ├── expenseRoutes.js
│   │   │   └── itemRoutes.js
│   │   ├── utils/streakCalculator.js      # Streak algorithm from habit logs
│   │   └── index.js                       # Express app entry point
│   ├── DailyKit_API.postman_collection.json # Ready-to-import Postman collection
│   ├── .env.example
│   ├── .env
│   └── package.json
│
└── dailykit_app/                           # Flutter Android App
    ├── lib/
    │   ├── core/
    │   │   ├── constants/
    │   │   │   ├── api_endpoints.dart     # Auto-detects 10.0.2.2 (Android) / localhost
    │   │   │   └── app_colors.dart        # Material 3 color palette
    │   │   ├── network/
    │   │   │   ├── api_client.dart        # Dio singleton + JWT interceptor
    │   │   │   └── offline_sync_queue.dart# Local offline queue manager
    │   │   ├── theme/app_theme.dart       # Material 3 Light & Dark themes
    │   │   └── utils/
    │   │       ├── currency_formatter.dart# Formats INR (₹) / custom currency
    │   │       └── notification_service.dart # Local notifications for reminders
    │   ├── models/
    │   │   ├── user_model.dart
    │   │   ├── habit_model.dart
    │   │   ├── expense_model.dart
    │   │   └── item_model.dart
    │   ├── providers/
    │   │   ├── auth_provider.dart
    │   │   ├── habit_provider.dart
    │   │   ├── expense_provider.dart
    │   │   ├── item_provider.dart
    │   │   └── settings_provider.dart
    │   ├── screens/
    │   │   ├── auth/                      # Login & Register screens
    │   │   ├── home/                      # RootNavigationScreen (Bottom Nav)
    │   │   ├── habits/                    # Habit Tracker, Heatmap, Add/Edit
    │   │   ├── expenses/                  # Quick-add (<5s), List, Charts, Categories
    │   │   ├── items/                     # Where I Kept It, Fast Search, Move Location
    │   │   └── settings/                  # Profile, Currency switch, Dark Mode
    │   ├── widgets/                       # Reusable UI components
    │   └── main.dart
    └── pubspec.yaml
```

---

## 🚀 Step-by-Step Run Instructions

### Step 1: Initialize MySQL 8 Database
1. Make sure your MySQL 8 service is running on your machine.
2. Open terminal and run the schema and seed scripts:
   ```bash
   mysql -u root -p < "backend/database/schema.sql"
   mysql -u root -p < "backend/database/seed.sql"
   ```
   *(Or run them via MySQL Workbench / phpMyAdmin / DBeaver).*

### Step 2: Configure & Start Backend
1. Open `backend/.env` and update your MySQL password:
   ```env
   PORT=3000
   DB_HOST=127.0.0.1
   DB_USER=root
   DB_PASSWORD=your_mysql_password
   DB_NAME=dailykit_db
   DB_PORT=3306
   JWT_SECRET=super_secret_dailykit_jwt_key_2026_xyz
   ```
2. Start the API server:
   ```bash
   cd backend
   npm start
   ```
3. Test health check:
   Open browser at `http://localhost:3000/api/health`
   You should see:
   ```json
   { "status": "online", "app": "DailyKit REST API", "version": "1.0.0" }
   ```

### Step 3: Run the Flutter App on Android Emulator

1. **Android Emulator Loopback:**
   Android emulators run in an isolated virtual network. The host computer's `localhost` is accessible from the Android emulator via IP **`10.0.2.2`**.
   *DailyKit automatically detects Android and routes all Dio requests to `http://10.0.2.2:3000/api`!*
2. **If testing on a physical Android device via USB:**
   Forward port 3000 from the device to your PC using ADB:
   ```bash
   adb reverse tcp:3000 tcp:3000
   ```
   Or change the host in `lib/core/constants/api_endpoints.dart` to your computer's local Wi-Fi IP (e.g., `http://192.168.1.5:3000/api`).
3. **Launch the Flutter app:**
   ```bash
   cd dailykit_app
   flutter run
   ```

---

## 🧪 Testing with Seed Data

A pre-configured demo account is included:
- **Email:** `demo@dailykit.com`
- **Password:** `password123`

On the app's Login screen, simply tap the **"Fill Demo Credentials"** button to instantly prefill and log in!

The demo user is pre-populated with:
- **Habits:** Morning Meditation, Read 20 Pages, Drink 3L Water, 30 Min Workout with active streaks.
- **Expenses:** Lunch at cafeteria, Metro recharge, Running shoes, Internet bill, and Health supplements with category charts.
- **Items:** Passport & Visa Docs, MacBook Charger, Bosch Power Drill (marked as lent to Rohan), and Spare Car Keys.

---

## 🛠️ Building the Release APK

To create an optimized production release APK for Android:

```bash
cd dailykit_app

# 1. Ensure dependencies are resolved
flutter pub get

# 2. Build release APK
flutter build apk --release
```

The compiled APK will be located at:
`dailykit_app/build/app/outputs/flutter-apk/app-release.apk`

To build an Android App Bundle (.aab) for Google Play Store:
```bash
flutter build appbundle --release
```
Output: `dailykit_app/build/app/outputs/bundle/release/app-release.aab`

#   H E W - A p p  
 