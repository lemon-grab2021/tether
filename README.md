# Tether

**Tether** is a real-time community messaging platform designed for small communities, societies, clubs, and social groups. The application supports both circle-based group conversations and one-to-one direct messaging, with additional focus on privacy, moderation, audit logging, media sharing, and user engagement.

This project was developed as a final-year Computer Science project and demonstrates a full-stack communication system using a NestJS backend, PostgreSQL database, WebSocket-based messaging, media upload support, and a Flutter frontend.

---

## Project Overview

Modern communities often rely on scattered communication tools, which can make it difficult to maintain trust, context, and meaningful engagement. Tether aims to provide a more focused communication space where users can create or join circles, send real-time messages, manage direct conversations, share media, and interact through a lightweight social connection feature called **Tether Pulse**.

The project focuses on:

- Real-time group and direct messaging
- Privacy-aware communication
- Media upload and scanning workflow
- Moderation support
- Audit logging for accountability
- Soft deletion and conversation recovery
- Notification handling
- A distinctive engagement feature through Tether Pulse

---

## Features

### Implemented Features

#### Authentication and User Accounts

- User registration
- User login
- JWT-based authentication
- Refresh-token session support
- Password hashing using Argon2
- Protected backend routes using authentication guards

#### Circle-Based Messaging

- Create and manage circles
- Join circle conversations
- Send and retrieve circle messages
- Real-time message delivery using WebSockets
- Circle member access protection

#### Direct Messaging

- Create or retrieve one-to-one conversations
- Send direct messages between users
- Retrieve conversation messages
- Soft-delete direct conversations
- Restore deleted direct conversations

#### Media Sharing

- Image and video attachment selection from the Flutter client
- Backend upload handling
- MinIO-based object storage integration
- Upload status tracking
- ClamAV-based malware scanning workflow

#### Notifications

- Notification model and backend service
- Notification list screen in the frontend
- Unread notification count support
- Notification bell in the app interface

#### Audit Logging and Moderation Support

- Backend audit logging service
- Audit entries for important user actions
- Hash-based audit log integrity support
- Merkle root/proof concept for moderation transparency
- Report-related database structure for moderation workflows

#### Tether Pulse

- A user engagement feature designed to show connection strength or social activity
- Provides Tether with a distinctive identity beyond standard messaging applications

#### Data Lifecycle Features

- Soft deletion for conversations
- Scheduled purge support for deleted direct conversations
- Database fields for tracking creation, update, and deletion timestamps

---

## Partially Implemented / Prototype Features

Some features exist as working prototypes or backend-supported concepts but may require further refinement before production use.

- Full persistent login restoration on app restart
- Complete end-to-end notification metadata handling
- Production-grade moderation transparency dashboard
- Advanced audit-log verification interface
- Complete automated test coverage
- Production deployment configuration
- User-facing account deletion/export workflow

---

## Future Improvements

The following improvements could be added in future versions:

- Push notifications for mobile devices
- Advanced circle roles and permissions
- Full-text search across messages
- Improved admin moderation dashboard
- User data export for GDPR compliance
- End-to-end encryption investigation
- Better message reactions and replies
- Typing indicators and read receipts
- Improved profile customisation
- Stronger automated testing and CI/CD pipeline
- Production deployment using cloud infrastructure

---

## Technology Stack

### Frontend

- Flutter
- Dart
- Provider for state management
- HTTP client for REST API communication
- WebSocket/socket-based real-time messaging
- File picker for media attachment selection
- Secure storage for authentication tokens

### Backend

- NestJS
- TypeScript
- Prisma ORM
- PostgreSQL
- Socket.IO / WebSocket gateway
- JWT authentication
- Argon2 password hashing
- MinIO for object storage
- ClamAV for malware scanning
- Redis support
- Docker Compose for local services

### Database

- PostgreSQL
- Prisma schema and migrations

### Infrastructure / Local Services

- Docker
- Docker Compose
- PostgreSQL container
- Redis container
- MinIO container
- ClamAV container

---

## Project Structure

```txt
tether-main/
│
├── apps/
│   ├── server/              # NestJS backend application
│   │   ├── src/
│   │   │   ├── auth/        # Authentication and session handling
│   │   │   ├── users/       # User-related logic
│   │   │   ├── circles/     # Circle/group functionality
│   │   │   ├── messages/    # Circle message functionality
│   │   │   ├── direct-messages/
│   │   │   ├── uploads/     # Media upload and scanning logic
│   │   │   ├── notifications/
│   │   │   ├── audit-log/
│   │   │   └── prisma/
│   │   │
│   │   ├── prisma/
│   │   │   └── schema.prisma
│   │   │
│   │   └── package.json
│   │
│   └── mobile/              # Flutter frontend application
│       ├── lib/
│       │   ├── screens/
│       │   ├── services/
│       │   ├── providers/
│       │   ├── models/
│       │   └── widgets/
│       │
│       └── pubspec.yaml
│
├── docker-compose.yml
├── package.json
└── README.md
