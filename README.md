# Crazy To-Do List App

A unique and visually stunning to-do list application built with Flutter and Firebase. This app uses anonymous authentication to provide each user with a private, personal task list without requiring sign-up.

## Features

- **Anonymous Authentication**: Users get a unique ID without needing to create an account
- **Private Task Management**: Each user can only access their own tasks
- **Stunning UI**: Animated backgrounds, confetti effects, and colorful task cards
- **Intuitive Gestures**: Swipe to delete tasks
- **Real-time Updates**: Tasks update instantly using Firestore streams

## Technologies Used

- **Flutter**: For the beautiful and responsive UI
- **Firebase Authentication**: For anonymous user authentication
- **Cloud Firestore**: For storing and managing task data
- **Firebase Security Rules**: To ensure data privacy
- **Flutter Animate**: For smooth animations
- **Lottie**: For loading animations
- **Confetti**: For celebration effects when completing tasks

## Setup Instructions

1. **Firebase Setup**:
   - Create a new Firebase project in the Firebase Console
   - Enable Anonymous Authentication
   - Set up Cloud Firestore and choose a location
   - Apply the security rules from `firestore.rules`

2. **Flutter Setup**:
   - Ensure Flutter is installed and up to date
   - Run `flutter pub get` to install dependencies
   - Connect your app to Firebase using the Firebase CLI or manual setup

3. **Run the App**:
   - Use `flutter run` to start the app in debug mode
   - Or build a release version with `flutter build apk --release`

## Firestore Security Rules

The app uses the following security rules to ensure data privacy:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to read and write only to their own data
    match /users/{userId}/tasks/{taskId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Deny access to all other paths
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Database Structure

- **Collection**: `users`
  - **Document**: `{user_uid}`
    - **Subcollection**: `tasks`
      - **Document**: `{task_id}`
        - **Fields**:
          - `title` (string)
          - `is_completed` (boolean)
          - `created_at` (timestamp)
          - `color` (number)
