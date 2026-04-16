# Quiz Master

Quiz Master is now a role-based Flutter + Dart exam portal with separate admin and client experiences. It includes local signup/login, admin-controlled exam settings, configurable question management, client exam and practice modes, leaderboard tracking, and a local AI-style analyzer for performance feedback.

## Highlights

- Login and signup flow with a default admin account
- Admin dashboard for exam title, question quantity, timer, shuffle, and practice controls
- Admin question bank management with add and delete support
- Client dashboard for exam mode, practice mode, leaderboard, and personal progress
- Local AI analyzer that generates feedback and recommendations after each attempt
- Persistent local storage for users, questions, settings, and progress

## Project Structure

```text
lib/
  controllers/
  data/
  models/
  screens/
  services/
  utils/
  widgets/
```

## Run the App

```bash
flutter pub get
flutter run
```

## Demo Admin Login

```text
Email: admin@quizmaster.com
Password: admin123
```

## Verify

```bash
flutter analyze
flutter test
```
