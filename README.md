# Student Command Center

A Flutter starter for a student management system with:

- splash-to-dashboard app flow
- district -> school -> class -> student drill-down
- student -> class -> school -> district drill-up
- mock analytics for score, attendance, and risk
- clean feature structure you can grow into a production app

## Tech Stack

- `flutter_riverpod` for state management
- `go_router` for navigation
- `fl_chart` for dashboard and trend charts
- `google_fonts` for a stronger visual identity

## Structure

```text
lib/
├── core/
│   ├── router/
│   └── theme/
└── features/
    └── student_management/
        ├── data/
        ├── domain/
        └── presentation/
```

## Screens

- `SplashScreen`: polished entry state before routing into the app
- `DashboardScreen`: KPI cards, charts, and build roadmap
- `HierarchyExplorerScreen`: multi-level drill-down analytics
- `StudentDetailScreen`: learner profile with drill-up actions

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## How To Extend

1. Replace `MockStudentManagementRepository` with your real API repository.
2. Add auth and role-based access before connecting live data.
3. Introduce local persistence for offline access and sync.
4. Move aggregation logic to the backend once the contracts stabilize.
# student_system
