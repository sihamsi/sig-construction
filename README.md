# 🏗️ SIG Construction

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![SQLite](https://img.shields.io/badge/SQLite-offline--first-003B57?logo=sqlite&logoColor=white)](https://www.sqlite.org)
[![Leaflet](https://img.shields.io/badge/Leaflet-1.x-199900?logo=leaflet&logoColor=white)](https://leafletjs.com)

**Offline-first GIS application for field surveying of constructions** — draw building footprints directly on an interactive map, classify them, and track survey activity through a role-based dashboard.

Built with Flutter, it runs on **Android, iOS, Windows, Linux, macOS and the web** from a single codebase.

<!-- Add screenshots here:
| Login | Map | Dashboard |
|---|---|---|
| ![login](docs/screenshots/login.png) | ![map](docs/screenshots/map.png) | ![dashboard](docs/screenshots/dashboard.png) |
-->

## ✨ Features

- 🗺️ **Interactive map** — Leaflet + Leaflet.Draw embedded in a WebView (bundled locally, works offline), with street/satellite layers
- ✏️ **Polygon drawing** — survey agents draw construction footprints on the map; geometries are stored as GeoJSON
- 🏘️ **Construction registry** — 9 construction types (residential, commercial, industrial, administrative, public facility, touristic, agricultural, mixed, other), each with its own color and attributes
- 👥 **Role-based access** — *agents* record surveys on the ground, *supervisors* oversee every agent's work
- 📊 **Dashboard** — per-type statistics and survey activity at a glance
- 🔌 **100% offline** — local SQLite database (`sqflite`, with FFI support on desktop); no backend required

## 🧱 Architecture

```
lib/
├── main.dart                    # App entry, theming (Material 3), auth screens
├── map_page.dart                # Leaflet map + drawing tools (WebView bridge)
├── constructions_list_page.dart # Registry with filters and details
├── dashboard_page.dart          # Statistics dashboard
├── construction_types.dart      # Types, colors and attributes catalog
└── data/
    ├── db/app_database.dart     # SQLite schema, seed and queries
    └── models/                  # Construction & User models
assets/map/                      # Leaflet + Leaflet.Draw bundled for offline use
```

## 🚀 Getting started

```bash
git clone https://github.com/sihamsi/sig-construction.git
cd sig-construction
flutter pub get
flutter run
```

On first launch the app creates its local database and seeds a demo account:

| Role | Username | Password |
|---|---|---|
| Supervisor | `supervisor` | `supervisor` |

New agents can be registered from the sign-up screen.

## ⚠️ Scope

This is a demo/learning project: authentication is intentionally simple (local accounts, no hashing) and all data stays on the device. Don't use it as-is to store real personal data.

## 👩‍💻 Authors

- [Siham Ait Oumghar](https://github.com/sihamsi)
- Meryem Benchelh
