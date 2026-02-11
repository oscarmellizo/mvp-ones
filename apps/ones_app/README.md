# ones_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Configuración por ambiente

La app lee configuración vía `--dart-define`.

Ejemplo (Flutter Web):

```bash
flutter run -d chrome \
  --dart-define=ONES_ENV=dev \
  --dart-define=ONES_API_BASE_URL=http://localhost:8080 \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

## Google Sign-In

- Mobile: usa el plugin `google_sign_in`.
- Web: el plugin usa Google Identity Services bajo el capó.
- Tras login, la app obtiene `idToken` y llama al backend con:
  - `Authorization: Bearer <idToken>`

No se commitean archivos sensibles:

- `google-services.json`
- `GoogleService-Info.plist`
