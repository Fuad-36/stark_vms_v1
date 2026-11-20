# Stark VMS (Vehicle Management System)

Stark VMS is a full-stack, enterprise-grade vehicle fleet management platform designed for tracking, registering, updating, and auditing vehicles within an organization. It consists of a secure **Spring Boot** REST API backend connected to a **MySQL** relational database and a responsive **Flutter Web** frontend.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Application Screenshots](#application-screenshots)
- [Prerequisites](#prerequisites)
- [Database Setup](#database-setup)
- [Environment Variables](#environment-variables)
- [Running the Backend](#running-the-backend)
- [Running the Frontend](#running-the-frontend)
- [Default Login (Development Only)](#default-login-development-only)
- [API Overview](#api-overview)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## Project Overview

### What Stark VMS Does
Stark VMS streamlines corporate fleet operations. Administrators can log into a secure dashboard, inspect the complete fleet list, register new vehicles with validated attributes, modify existing records, and delete decommissioned vehicles. All actions are authenticated via JSON Web Tokens (JWT) and enforced through database constraints and business validations.

### Main Features
- **Stateless JWT Authentication**: Secure role-based login (`ROLE_ADMIN`) with Bearer token authentication on all protected endpoints.
- **Full Fleet CRUD**: View, create, update, and delete vehicle registrations in real time.
- **Duplicate Prevention**: Vehicle registration numbers are enforced unique at both the service layer (with automatic trimming and uppercase normalization) and via a MySQL unique index constraint (`uk_vehicle_number`).
- **Responsive UI & Inline Field Validation**: Built with Flutter Web; features a modern data table on desktop, cards on mobile, and field-level error messages (e.g. duplicate number warnings rendered directly beneath the affected input).
- **Graceful Session Handling**: Centralized client-side 401 interceptor that automatically logs out the user and clears cache when authentication expires.
- **Enterprise Security**: BCrypt password hashing, stateless security filters, and strict CORS handling.

### Technology Stack
- **Backend**:
  - Java 21 LTS
  - Spring Boot 4.1.x / Spring Security 6
  - Spring Data JPA / Hibernate ORM
  - JJWT (JSON Web Token) 0.12.6
  - MySQL Connector/J
  - Maven
- **Frontend**:
  - Flutter 3.13+ (Dart SDK `^3.13.4`)
  - Provider (State management)
  - `http` package for REST networking
  - `shared_preferences` for local token caching
- **Database**:
  - MySQL 8.0+

---

## Application Screenshots

> *Add your application screenshots to the [`docs/screenshots/`](docs/screenshots/) folder to display them here.*

| Login Screen | Fleet Dashboard (Desktop View) |
| :---: | :---: |
| ![Login Screen](docs/screenshots/login.png) | ![Vehicle Fleet List](docs/screenshots/vehicle-list.png) |
| *Authentication & Role-based Access* | *Real-time Vehicle List with Sorting* |

| Add / Edit Vehicle Modal | Duplicate Error Inline Handling |
| :---: | :---: |
| ![Add/Edit Vehicle](docs/screenshots/vehicle-form.png) | ![Duplicate Error](docs/screenshots/duplicate-error.png) |
| *Create & Update Vehicle Attributes* | *Inline Field-Level 409 Conflict Feedback* |

---

## Prerequisites

Before setting up Stark VMS, ensure the following tools are installed on your machine:

| Tool | Version Requirement | Verification Command | Notes |
| :--- | :--- | :--- | :--- |
| **Java JDK** | 21 LTS | `java -version` | Required by the backend Spring Boot framework. |
| **Maven** | 3.9+ (or use wrapper) | `./mvnw -v` or `mvn -v` | Maven wrapper (`mvnw` / `mvnw.cmd`) is included in `backend/`. |
| **Flutter SDK** | 3.13.4+ | `flutter --version` | Ensure the web toolchain is enabled: `flutter config --enable-web`. |
| **MySQL Server** | 8.0+ | `mysql --version` | Running locally on port `3306` (or accessible over network). |
| **Google Chrome** | Latest stable | `google-chrome --version` | Recommended browser for testing Flutter Web. |

---

## Database Setup

Stark VMS requires a MySQL database instance.

### 1. Create the Database
Log into your MySQL CLI or GUI tool (such as MySQL Workbench or DBeaver) as an administrative user:

```bash
mysql -u root -p
```

Create the application database (and optionally a dedicated test database):

```sql
-- Production / Development database
CREATE DATABASE stark_vms
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Optional: Test database for running integration test suites
CREATE DATABASE stark_vms_test
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
```

### 2. Schema and Migration
The backend is configured with:
```properties
spring.jpa.hibernate.ddl-auto=update
```
Hibernate automatically generates and updates the required database tables (`users`, `vehicles`) and constraints (`uk_vehicle_number`, `uk_users_username`) on first launch. No manual SQL DDL migration files are needed.

### 3. Verify Database Connection
You can verify MySQL connectivity from your terminal:

```bash
mysql -u root -p -e "SHOW DATABASES LIKE 'stark_vms%';"
```

---

## Environment Variables

All sensitive values and environment-specific settings are parameterized using environment variables with development-safe fallbacks.

### Backend Environment Variables (`backend/src/main/resources/application.properties`)

| Variable Name | Purpose | Required in Dev? | Default / Fallback | Example Value | Where Configured |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `DB_URL` | JDBC connection URL for MySQL | No | `jdbc:mysql://localhost:3306/stark_vms` | `jdbc:mysql://127.0.0.1:3306/stark_vms?useSSL=false&serverTimezone=UTC` | Environment / Shell |
| `DB_USERNAME` | MySQL database user | No | `root` | `stark_user` | Environment / Shell |
| `DB_PASSWORD` | MySQL database user password | **Yes** | *None* (empty) | `YourSecurePassword123!` | Environment / Shell |
| `SERVER_PORT` | HTTP port for the backend server | No | `8080` | `8080` | Environment / Shell |
| `JWT_SECRET` | Secret key used to sign and verify HMAC-SHA256 JWTs (minimum 32 characters / 256 bits) | No (Dev) / **Yes** (Prod) | Hardcoded 256-bit dev key in `application.properties` | `your-cryptographically-secure-random-256-bit-key-32-chars` | Environment / Shell |

> [!WARNING]
> In production environments, never rely on default JWT secrets or empty database passwords. Always export a unique `JWT_SECRET` and `DB_PASSWORD`.

### Frontend Environment Variables (`frontend/lib/config/api_config.dart`)

| Variable Name | Purpose | Required in Dev? | Default / Fallback | Example Value | Where Configured |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `API_BASE_URL` | Base HTTP endpoint of the backend REST API | No | `http://localhost:8080` | `http://localhost:8080` or `https://api.starkvms.com` | Flutter build/run flag (`--dart-define`) |

---

## Running the Backend

The backend directory contains the Spring Boot application and the Maven wrapper.

### Step 1: Navigate to Backend Directory
```bash
cd backend
```

### Step 2: Set Environment Variables

**On Linux / macOS:**
```bash
export DB_URL="jdbc:mysql://localhost:3306/stark_vms?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
export DB_USERNAME="root"
export DB_PASSWORD="your_mysql_password"
export SERVER_PORT=8080
export JWT_SECRET="c3Rhcmstdm1zLXNlY3JldC1qd3Qta2V5LWZvci1kZXZlbG9wbWVudC1vbmx5LTI1NmJpdHM="
```

**On Windows (PowerShell):**
```powershell
$env:DB_URL="jdbc:mysql://localhost:3306/stark_vms?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
$env:DB_USERNAME="root"
$env:DB_PASSWORD="your_mysql_password"
$env:SERVER_PORT="8080"
$env:JWT_SECRET="c3Rhcmstdm1zLXNlY3JldC1qd3Qta2V5LWZvci1kZXZlbG9wbWVudC1vbmx5LTI1NmJpdHM="
```

**On Windows (Command Prompt `cmd.exe`):**
```cmd
set DB_URL=jdbc:mysql://localhost:3306/stark_vms?useSSL=false^&allowPublicKeyRetrieval=true^&serverTimezone=UTC
set DB_USERNAME=root
set DB_PASSWORD=your_mysql_password
set SERVER_PORT=8080
set JWT_SECRET=c3Rhcmstdm1zLXNlY3JldC1qd3Qta2V5LWZvci1kZXZlbG9wbWVudC1vbmx5LTI1NmJpdHM=
```

### Step 3: Start the Backend Server

**On Linux / macOS:**
```bash
./mvnw spring-boot:run
```

**On Windows:**
```powershell
.\mvnw.cmd spring-boot:run
```

### Expected Startup Output
The application starts at:
```
http://localhost:8080
```

### Verify Health Check
Open your browser or run curl to test the public health endpoint:
```bash
curl http://localhost:8080/api/health
```
**Expected Response:**
```json
{"status":"UP"}
```

---

## Running the Frontend

The frontend is a Flutter Web application located in the `frontend` directory.

### Step 1: Navigate to Frontend Directory
```bash
cd frontend
```

### Step 2: Install Dependencies
```bash
flutter pub get
```

### Step 3: Start Flutter Web in Development Mode
Run the application targetting Google Chrome with the `API_BASE_URL` defined:

```bash
flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:8080
```

- `--web-port=3000`: Ensures the frontend runs on a consistent local port matching backend CORS presets.
- `--dart-define=API_BASE_URL=...`: Injects the backend API location into `ApiConfig`.

### Expected Frontend URL
Once built, Chrome automatically opens:
```
http://localhost:3000
```

---

## Default Login (Development Only)

When the backend application boots up, `AdminUserSeeder` checks if the `users` table is completely empty. If empty, it automatically provisions an initial administrator account.

> [!NOTE]
> **DEVELOPMENT ONLY CREDENTIALS**
> - **Username**: `admin`
> - **Password**: `Admin@123`
> - **Role**: `ADMIN`
>
> **Source confirmation**: [AdminUserSeeder.java](file:///D:/WORKS/stark-vms-v1/backend/src/main/java/com/stark_vms_v1/backend/config/AdminUserSeeder.java#L41-L49) stores the password strictly as a BCrypt hash (`passwordEncoder.encode("Admin@123")`).
>
> > [!WARNING]
> > If deploying to production, ensure an initial administrator is created via a secure migration script or immediately change the password after first boot.

---

## API Overview

All protected endpoints require the HTTP header:
`Authorization: Bearer <jwt-token>`

| Method | Endpoint | Access | Description | Request Body | Success Status |
| :--- | :--- | :---: | :--- | :--- | :---: |
| `GET` | `/api/health` | Public | Backend health inspection | *None* | `200 OK` |
| `POST` | `/api/auth/login` | Public | Authenticates user and issues JWT | `{"username":"admin","password":"..."}` | `200 OK` |
| `GET` | `/api/vehicles` | `ADMIN` | Returns all vehicles ordered by `createdAt DESC, id DESC` | *None* | `200 OK` |
| `GET` | `/api/vehicles/{id}` | `ADMIN` | Fetches a vehicle by ID | *None* | `200 OK` |
| `POST` | `/api/vehicles` | `ADMIN` | Creates a new vehicle record | JSON `VehicleRequest` (see schema below) | `201 Created` |
| `PUT` | `/api/vehicles/{id}` | `ADMIN` | Updates an existing vehicle record | JSON `VehicleRequest` (see schema below) | `200 OK` |
| `DELETE` | `/api/vehicles/{id}` | `ADMIN` | Deletes a vehicle by ID | *None* | `204 No Content` |

### `VehicleRequest` Schema
```json
{
  "vehicleNumber": "DHK-11-2233",
  "type": "CAR",
  "brand": "Toyota",
  "model": "Corolla",
  "year": 2023
}
```
- Supported `type` enum values: `CAR`, `BUS`, `TRUCK`, `MOTORCYCLE`.
- `year`: Must be between `1886` and the current calendar year.
- `vehicleNumber`: Maximum 20 characters, automatically trimmed and capitalized.

---

## Testing

### Backend Unit & Integration Tests
The backend test suite includes repository tests, web security filter verifications, controller mock tests, and integration tests with transactional rollback.

To run the backend tests:
```bash
cd backend
# Linux/macOS:
./mvnw test
# Windows:
.\mvnw.cmd test
```

### Frontend Widget & Integration Tests
The Flutter test suite covers authentication flows, CRUD operations, route navigation guards, 401 token invalidation, and inline 409 duplicate error handling.

To run the frontend tests:
```bash
cd frontend
flutter test
```

---

## Troubleshooting

### 1. MySQL Connection Failure / Access Denied
- **Symptom**: `CommunicationsException: Communications link failure` or `Access denied for user 'root'@'localhost'`.
- **Solution**:
  1. Verify MySQL is active: `mysqladmin -u root -p ping`.
  2. Confirm the database exists: `mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS stark_vms;"`.
  3. Verify your `$env:DB_PASSWORD` or `export DB_PASSWORD=...` matches your MySQL root password.

### 2. Port Conflicts (`Port 8080 is already in use`)
- **Symptom**: `Web server failed to start. Port 8080 was already in use.`
- **Solution**:
  - Identify the process occupying port 8080:
    - **Windows**: `netstat -ano | findstr :8080` then kill with `taskkill /PID <PID> /F`.
    - **Linux/macOS**: `lsof -i :8080` then `kill -9 <PID>`.
  - Or run the backend on a different port: `SERVER_PORT=8081 ./mvnw spring-boot:run` and pass `--dart-define=API_BASE_URL=http://localhost:8081` to Flutter.

### 3. Backend Unavailable from Flutter Web / CORS Errors
- **Symptom**: Browser console displays `Access to XMLHttpRequest at 'http://localhost:8080/...' has been blocked by CORS policy`.
- **Solution**:
  - The backend's [SecurityConfig.java](file:///D:/WORKS/stark-vms-v1/backend/src/main/java/com/stark_vms_v1/backend/config/SecurityConfig.java#L94-L106) allows origins matching `http://localhost:*` and `http://127.0.0.1:*`.
  - Always launch Flutter with a localhost port, e.g.:
    ```bash
    flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:8080
    ```
  - Ensure the browser does not navigate to an unlisted IP address or hostname not in the CORS allowed origins list.

### 4. Invalid or Expired JWT Token
- **Symptom**: API calls suddenly fail with HTTP `401 Unauthorized` or Flutter displays an authentication expiration banner.
- **Solution**:
  - Tokens expire after 3,600 seconds (1 hour) by default.
  - The Flutter app automatically catches 401s and clears local storage, redirecting you back to `/login`. Simply log in again to receive a fresh token.

### 5. Flutter Dependency or Build Issues
- **Symptom**: `Error on line ... of pubspec.yaml` or build cache corruption.
- **Solution**:
  ```bash
  cd frontend
  flutter clean
  flutter pub get
  ```
