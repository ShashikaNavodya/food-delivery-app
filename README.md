# Savor — Food delivery app

A Flutter food-delivery app with restaurant discovery, menu browsing, a single-restaurant cart, checkout, and persisted order tracking. Customer accounts, delivery addresses, card-payment demo records, restaurant products, and orders are managed by a Node.js REST API backed by SQLite.

## Requirements

- Flutter 3.24+ and Dart
- Node.js 22.5+ (the API uses the built-in `node:sqlite` module; no npm packages are required)

## Run locally

1. Start the API:

   ```powershell
   cd backend
   npm start
   ```

   The API listens on `http://localhost:4000`. SQLite creates `backend/data/savor.sqlite` and seeds 12 shops with 26 menu/product items. Seeding is additive and idempotent, so existing databases receive new catalog entries on the next API start without overwriting saved users, addresses, or orders.

2. In a second terminal, run the Flutter app:

   ```powershell
   flutter pub get
   flutter run
   ```

   The app uses `localhost` on web and desktop, and `10.0.2.2` for the Android emulator. For a physical device, change the API host in `lib/core/config/api_config.dart` to the computer's LAN address and ensure both devices are on the same network. Login tokens are kept in platform secure storage.

   Android/iOS development builds allow cleartext HTTP for the local API. Use HTTPS and restrict these settings before shipping a production app.

## API

All routes are prefixed with `/api`.

| Method | Route | Description |
| --- | --- | --- |
| `GET` | `/health` | API and SQLite health |
| `GET` | `/restaurants?search=...` | Restaurant listings and search |
| `GET` | `/restaurants/:id/menu` | Menu items for one restaurant |
| `POST` | `/auth/register` | Create an account and sign in |
| `POST` | `/auth/login` | Sign in |
| `GET` | `/auth/me` | Get the current account (Bearer token) |
| `POST` | `/auth/logout` | Revoke a session |
| `GET` | `/addresses` | List the signed-in user's saved delivery addresses |
| `POST` | `/addresses` | Save an address |
| `PATCH` | `/addresses/:id` | Edit a saved address |
| `PUT` | `/addresses/:id/default` | Choose the default delivery address |
| `POST` | `/payments/authorize` | Authorize the card-payment demo |
| `POST` | `/orders` | Validate and create an authenticated delivery order |
| `GET` | `/orders` | Signed-in user's order history |
| `GET` | `/orders/:id` | One of the signed-in user's tracking summaries |
| `PATCH` | `/orders/:id` | Advance an order by one tracking status (operator key required) |

Example order request:

```json
{
  "address": "12 Flower Road, Colombo 07",
  "items": [
    { "menuItemId": 501, "quantity": 2 }
  ]
}
```

The server looks up menu prices and delivery fees in SQLite, requires all order items to belong to one restaurant, validates quantities/address, and stores the order and its items in one transaction. The catalog is seeded into the `restaurants` and `menu_items` SQL tables. Customer accounts are created through registration and saved in the `users` table; no shared demo account or default password is inserted. User passwords are salted and hashed with Node.js `scrypt`; API sessions are random, expire after 30 days, and are stored hashed in SQLite. Accounts, addresses, payments, and orders are isolated per signed-in user.

Order statuses progress from `Confirmed` → `Preparing` → `On the way` → `Delivered`. Customer sign-in and per-account order/address handling are included; a separate restaurant/operator dashboard is not.

Set `API_ADMIN_KEY` on the server before using the order status update route; supply the same value in the `X-Admin-Key` header. The checkout's card screen is a clearly-labelled **demo only**. No real card charge is made, and complete card details are not sent to or saved by the server. Any valid-looking test card is approved; a number ending in `0002` demonstrates a decline. Cash on delivery is also available.

## Tests and analysis

```powershell
flutter analyze
flutter test
cd backend
npm test
```

Restaurant and menu photography is loaded from Unsplash, so images require an internet connection.
