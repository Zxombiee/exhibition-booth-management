# Exhibition Booth Management App

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter" />
  <img src="https://img.shields.io/badge/Firebase-Firestore-orange?logo=firebase" />
  <img src="https://img.shields.io/badge/Platform-Android-green?logo=android" />
  <img src="https://img.shields.io/badge/Course-ISB26603-navy" />
</p>

A Flutter mobile application for managing the complete lifecycle of trade shows and exhibitions. Built for **ISB26603 Mobile and Ubiquitous Computing** at Universiti Kuala Lumpur MIIT.

---

## 📱 About

This app replaces the traditional manual process of booking exhibition booths (by phone or email) with a fully digital platform. Exhibition organizers create and publish events, exhibitors browse those events and book specific booth spaces on an **interactive coordinate-based floor map**, and administrators oversee the entire system from a central dashboard.

---

## 👥 User Roles

| Role | Description |
|---|---|
| **Guest** | Browse published exhibitions and view read-only floor plan without login |
| **Exhibitor** | Browse events, select booths on interactive map, submit applications |
| **Organizer** | Create and manage events, approve or reject applications |
| **Admin** | Full system control — users, exhibitions, floor plans, all reservations |

---

## ✨ Features

### Guest
- Browse published exhibitions with search and status filter
- View event details with venue photo and read-only interactive booth map
- Guided to register/login to book

### Exhibitor
- Browse all published events with search and filter
- Interactive floor plan with colour-coded booths (🟢 Available · 🔴 Booked · 🔵 Selected)
- Tap booth to view details and add to cart
- Booth application form with company info, exhibit profile and add-ons
- My Applications — Pending, Approved, Rejected tabs
- Edit pending application, cancel, or re-apply after rejection

### Organizer
- Full CRUD for own exhibitions
- Publish/unpublish events, upload venue photo and floor plan image
- Review pending applications — approve, reject with reason, or cancel

### Admin
- Digital booth mapping — place, move, resize booths on coordinate grid
- Manual X Y coordinate input for precise booth placement
- Live coordinate badge while touching the map
- Stage placement with drag and resize
- Manage all exhibitions, users, and reservations system-wide

---

## 🗂️ Project Structure

```
lib/
├── main.dart                   # App entry point, Firebase init, Provider, Google Fonts
├── app_router.dart             # go_router navigation with role-based redirect
├── firebase_options.dart       # Firebase configuration
├── models/
│   ├── exhibition_model.dart   # Exhibition data model
│   └── user_model.dart         # User data model
├── providers/
│   └── auth_provider.dart      # Global auth state (Provider + SharedPreferences)
├── services/
│   └── auth_service.dart       # Firebase Auth + flutter_secure_storage
└── screens/
    ├── guest_home_screen.dart
    ├── event_details_screen.dart
    ├── login_screen.dart
    ├── register_screen.dart
    ├── exhibitor_dashboard.dart
    ├── browse_events_screen.dart
    ├── floor_plan_screen.dart
    ├── application_form_screen.dart
    ├── my_applications_screen.dart
    ├── organizer_dashboard.dart
    ├── my_events_screen.dart
    ├── pending_applications_screen.dart
    ├── create_event_screen.dart
    ├── admin_dashboard.dart
    ├── admin_floor_plan_screen.dart
    ├── manage_exhibitions_screen.dart
    ├── manage_users_screen.dart
    └── all_reservations_screen.dart
```

---

## 🗄️ Database Design

**Database name:** `exhibition_booth_management`  
**Backend:** Cloud Firestore (NoSQL)

| Collection | Description |
|---|---|
| `users` | User accounts with role (exhibitor / organizer / admin) |
| `exhibitions` | Exhibition events with booth types, images, coordinates |
| `booths` | Individual booths with normalized X Y W H coordinates |
| `applications` | Booking applications with status, company info, add-ons |

---

## 📦 Packages Used

| Package | Version | Purpose |
|---|---|---|
| firebase_core | ^3.13.0 | Firebase initialization |
| firebase_auth | ^5.5.1 | Authentication & role-based access |
| cloud_firestore | ^5.6.5 | NoSQL database & real-time updates |
| firebase_storage | ^12.4.4 | Venue photo & floor plan image storage |
| go_router | ^14.0.0 | Navigation with auth protection |
| image_picker | ^1.1.2 | Pick images from device gallery |
| cached_network_image | ^3.4.1 | Efficient image loading & caching |
| intl | ^0.20.2 | Date formatting throughout the app |
| google_fonts | ^6.2.1 | Poppins font applied app-wide |
| provider | ^6.1.2 | Global auth state management |
| shared_preferences | ^2.5.3 | Local role caching after login |
| flutter_secure_storage | ^9.2.4 | Encrypted UID & token storage |

---

## 🚀 Getting Started

### Prerequisites
- Flutter 3.x
- Android Studio / VS Code
- Firebase project (with Firestore, Auth, Storage enabled)
- Android device or emulator (API 21+)

### Setup

1. **Clone the repository**
```bash
git clone https://github.com/Zxombiee/exhibition-booth-management.git
cd exhibition-booth-management
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure Firebase**
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Enable Authentication (Email/Password), Firestore, and Storage
   - Download `google-services.json` and place it in `android/app/`
   - Update `lib/firebase_options.dart` with your project config

4. **Run the app**
```bash
flutter run
```

---

## 👨‍💻 Team

| Name | Student ID | Role |
|---|---|---|
| Nurul Farzanah Mukminin Binti Rozaidi |  | Wireframes, Cover, Plagiarism, Peer Evaluation |
| Nur Aiman Nabil Bin Aidil Ashar |  | Main Application Development, GitHub |
| Muhammad Irfan Danial Bin Mohd Nadzir | | Requirements Analysis, User Guide |
| Muhammad Malek Danish Bin Hazizan | | SDLC, Module Division, Database Design |

---

## 📚 Course Details

| | |
|---|---|
| **Course** | ISB26603 Mobile and Ubiquitous Computing |
| **Institution** | Malaysian Institute of Information Technology (MIIT), UniKL |
| **Lecturer** | Dr. Chen Xinyuan |
| **Semester** | March 2026 |
