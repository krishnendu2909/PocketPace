
# PocketPace 💰

### Take Control of Your Money, One Step at a Time.

PocketPace is a personal finance management application built with Flutter and SQLite. It helps users track expenses, manage budgets, monitor spending habits, and stay informed about their financial activity.

The application is designed with a simple interface, local data storage, and practical financial management tools.

## ✨ Features

- **Dashboard:** View your financial activity and safe-to-spend balance.
- **Transaction Management:** Add and review income and expenses.
- **Category Budgets:** Set spending limits and monitor category-wise expenses.
- **Insights:** Compare monthly spending and analyse expense patterns.
- **Monthly Reports:** Review financial summaries and export PDF reports.
- **Recurring Transactions:** Manage scheduled income and expenses.
- **Budget Notifications:** Receive alerts about budget activity.
- **Monthly Backup Reminder:** Get reminded to back up your financial data.
- **Backup and Restore:** Export and restore application data using JSON backups.
- **Dark Mode:** Switch between light and dark themes.

## 🛠️ Technology Stack

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform application development |
| Dart | Application programming language |
| SQLite | Local database |
| Material UI | User interface components |
| Workmanager | Background task processing |
| Local Notifications | Reminders and alerts |

## 📁 Project Structure

```text
lib/
├── main.dart
├── app.dart
├── theme/
│   └── app_theme.dart
├── models/
│   ├── budget_profile.dart
│   ├── transaction_record.dart
│   └── recurring_transaction.dart
├── data/
│   └── local_database.dart
├── services/
│   ├── notification_service.dart
│   ├── recurring_transaction_service.dart
│   ├── background_task_service.dart
│   └── backup_service.dart
└── features/
    ├── onboarding/
    ├── dashboard/
    ├── insights/
    ├── transactions/
    ├── budgets/
    ├── reports/
    └── recurring/
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK
- Android Studio or Visual Studio Code
- Android Emulator or physical Android device

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/krishnendu2909/PocketPace.git
   ```

2. Navigate to the project directory:

   ```bash
   cd PocketPace
   ```

3. Install dependencies:

   ```bash
   flutter pub get
   ```

4. Run the application:

   ```bash
   flutter run
   ```

## 💾 Data Management

PocketPace uses local SQLite storage for financial records.

Users can:
- Create JSON backups of application data.
- Restore data from a previously created backup.
- Receive monthly reminders to create backups.

**Privacy:** Financial records are stored locally on the device. Keep exported backup files secure because they may contain sensitive financial information.

## 🧪 Quality Checks

Run Flutter static analysis:

```bash
flutter analyze
```

Run automated tests:

```bash
flutter test
```

## 📸 Screenshots

Screenshots and application demonstrations will be added here.

## 🗺️ Roadmap

- [ ] Complete application testing
- [ ] Finalise application branding and icon
- [ ] Improve documentation and screenshots
- [ ] Prepare signed Android release
- [ ] Publish the first stable release

## 🤝 Contributions

Suggestions, bug reports, and contributions are welcome.

Please open an issue before submitting major changes.

