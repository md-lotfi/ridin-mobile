# Ridin: System Architecture Diagrams

This document contains all formal Mermaid architectural diagrams preserving the complete design of the **Ridin** platform, including the Business Owner Protection & Fleet Value Suite.

---

## 1. Owner Value Proposition & Problem-Solving Flowchart

```mermaid
flowchart LR
    subgraph OwnerPain["Owner's Daily Headaches"]
        P1["Parent Disputes & Complaints ('Bus never came!')"]
        P2["Child Abandonment Liability (Sleeping child in hot bus)"]
        P3["Speeding, Detours & Fuel Wastage (Driver Misbehavior)"]
        P4["Flooded Phone Lines Every Morning (Anxious Parents)"]
        P5["Breakdowns & Expired Papers (Contrôle technique, Insurance)"]
    end

    subgraph RidinSolutions["Ridin Business-Owner Solutions"]
        S1["Proof of Service & Dispute Resolver (1-Click PDF/WhatsApp GPS Blackbox)"]
        S2["'No Child Left Behind' Inspection (Rear QR/NFC Scan + Manifest Reconciliation)"]
        S3["Real-Time Speed Radar + Daily Driver Scorecards"]
        S4["Peace-of-Mind Suite (Live ETA, 1-Click Delay Broadcast, 'Arrived at School' Alert)"]
        S5["Fleet Health & Compliance Tracker (GPS Odometer, Maintenance & Expiry Alerts)"]
    end

    P1 --> S1
    P2 --> S2
    P3 --> S3
    P4 --> S4
    P5 --> S5
```

---

## 2. Multi-Tier High-Level Architecture & Communication Topology

```mermaid
flowchart TD
    subgraph SuperAdminLayer["Platform Super-Admin (Platform Owner)"]
        FilaPanel["Filament Admin Dashboard (/super-admin) [Guard: admin]"]
        FilaPanel -->|"Manages"| TenancyMgmt["Organizations & Subscription Billing"]
        FilaPanel -->|"Manages"| GeoData["58 Wilayas & 1541 Communes"]
        FilaPanel -->|"Configures"| Gateways["Payment Gateways (Chargily, OCPay, CCP)"]
        FilaPanel -->|"Subscribes"| GlobalRadarSub["Centrifugo: platform:fleet"]
    end

    subgraph BusinessAdminLayer["Business Admin (School / Fleet Owner)"]
        LivewirePortal["Custom Livewire Portal (Flux + MaryUI) [Guard: web + Spatie Teams]"]
        LivewirePortal -->|"Monitors"| ExecDashboard["Executive ROI & Safety Command Center"]
        LivewirePortal -->|"Generates"| DisputeReports["1-Click Dispute Resolver (PDF/WhatsApp)"]
        LivewirePortal -->|"Tracks"| FleetHealth["Fleet Health & Compliance (Odometer, Insurance, Contrôle)"]
        LivewirePortal -->|"Dispatches & Ends"| TripDispatch["Daily Routes & On-Demand Trips (Manual Lifecycle)"]
        LivewirePortal -->|"Approves/Rejects"| StopApprovalQueue["Parent Pickup Stop Map Queue"]
        LivewirePortal -->|"Subscribes"| OrgFleetSub["Centrifugo: org:{orgId}:fleet"]
    end

    subgraph BackendEngine["Core Backend (Laravel 13 + PostgreSQL + PostGIS)"]
        Postgres[(PostgreSQL + PostGIS)]
        CentrifugoBroadcaster["CentrifugoBroadcaster (Mindcare Pattern)"]
        SpatialEngine["PostGIS Proximity Engine (ST_DWithin)"]
        FCMService["Firebase Cloud Messaging (FCM)"]
        PaymentManager["GatewayManager (Chargily / OCPay / CCP)"]
    end

    subgraph CentrifugoLayer["Centrifugo Real-Time Service (Go + Redis Engine)"]
        CentrifugoServer["Centrifugo Server (WSS: /connection/websocket)"]
        RedisPubSub[(Redis Engine)]
        CentrifugoServer <--> RedisPubSub
    end

    subgraph MobileAppLayer["Unified Mobile App (Flutter)"]
        DriverApp["Master: Driver Cockpit (Foreground Service GPS)"]
        ParentApp["Client: Parent Tracking (Live Map & ETA)"]
    end

    DriverApp -->|"1. GPS Pings (REST POST every 3-5s)"| SpatialEngine
    SpatialEngine -->|"2. ST_DWithin & Spatial Logs"| Postgres
    SpatialEngine -->|"3. HTTP Publish (API Key)"| CentrifugoBroadcaster
    CentrifugoBroadcaster -->|"4. Publish payload"| CentrifugoServer
    SpatialEngine -->|"5. Outer 1000m / Inner 100m Alerts (Guard against stale pings)"| FCMService

    CentrifugoServer -->|"6. Broadcast trip:{id} pins (<5ms)"| ParentApp
    CentrifugoServer -->|"6b. Broadcast org:{id}:fleet"| LivewirePortal
    CentrifugoServer -->|"6c. Broadcast platform:fleet"| FilaPanel
    FCMService -->|"7. Approaching & Arrival Alerts (Parent Locale)"| ParentApp

    ParentApp -->|"8. Acknowledge [Ready / 2 Mins Late]"| SpatialEngine
    ParentApp -->|"8b. Mark 'Absent Today' (Auto-skips stop)"| SpatialEngine
    SpatialEngine -->|"9. Publish driver:{driverId}"| CentrifugoBroadcaster
    CentrifugoBroadcaster -->|"10. StopAcknowledged / StopSkipped event"| CentrifugoServer
    CentrifugoServer -->|"11. Green Badge (Ready) / Gray (Absent)"| DriverApp
    DriverApp -->|"12. If 100m Unresponsive: Fallback Call/WhatsApp/SMS/Siren"| ParentApp
    DriverApp -->|"13. End of Trip: Rear QR/NFC Scan + Safety Checklist"| SpatialEngine
```

---

## 3. PostgreSQL + PostGIS Database Entity Relationship Diagram

```mermaid
erDiagram
    ORGANIZATIONS ||--o{ ORGANIZATION_WILAYAS : "covers"
    WILAYAS ||--o{ ORGANIZATION_WILAYAS : "assigned to"
    WILAYAS ||--o{ COMMUNES : "contains"

    ORGANIZATIONS ||--o{ USERS : "employs"
    ORGANIZATIONS ||--o{ VEHICLES : "owns"
    ORGANIZATIONS ||--o{ SUBSCRIPTIONS : "subscribes"
    ORGANIZATIONS ||--o{ ON_DEMAND_ORDERS : "purchases"

    USERS ||--o{ CHILDREN : "parents"
    USERS ||--o{ TRIPS : "drives (driver)"

    VEHICLES ||--o{ TRIPS : "assigned to"
    VEHICLES ||--o{ VEHICLE_MAINTENANCES : "logs"

    CHILDREN ||--o{ STOPS : "assigned to"
    STOPS ||--o{ TRIP_STOPS : "visited in"
    TRIPS ||--o{ TRIP_STOPS : "executes"
    TRIPS ||--o{ TRIP_LOCATIONS : "records"
    TRIPS ||--o{ TRIP_VIOLATIONS : "tracks"

    ORGANIZATIONS {
        ulid id PK
        string name
        string slug UK
        string status
        int on_demand_credits
        enum child_check_mode
    }

    VEHICLES {
        ulid id PK
        ulid organization_id FK
        ulid driver_id FK
        string plate_number UK
        string invite_code UK
        int capacity
        int current_odometer_km
        date insurance_expires_at
        date inspection_expires_at
        int last_oil_change_km
    }

    TRIPS {
        ulid id PK
        ulid organization_id FK
        ulid vehicle_id FK
        ulid driver_id FK
        enum trip_type
        enum status
        timestamp child_check_verified_at
        string child_check_method
        timestamp started_at
        timestamp ended_at
    }

    TRIP_STOPS {
        ulid id PK
        ulid trip_id FK
        ulid stop_id FK
        timestamp alert_outer_sent_at
        timestamp alert_inner_sent_at
        timestamp arrived_at
        timestamp departed_at
        int wait_duration_seconds
        timestamp call_attempted_at
        enum acknowledgement_status
        enum completion_status
    }

    TRIP_VIOLATIONS {
        bigint id PK
        ulid trip_id FK
        ulid driver_id FK
        enum violation_type
        float speed_kmh
        geography location
        timestamp recorded_at
    }
```

---

## 4. Two-Zone Geofence & Fallback Communication Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    actor Driver as Driver Cockpit (Master App)
    participant Backend as Laravel + PostGIS Spatial Engine
    participant Centrifugo as Centrifugo Real-Time Service
    participant FCM as Firebase Cloud Messaging
    actor Parent as Parent Tracking (Client App)

    Driver->>Backend: GPS Ping (lat, lng, speed, heading)
    Backend->>Backend: PostGIS ST_DWithin check on uncompleted stops

    alt Distance <= 1000m (Outer Zone) & Not Yet Alerted
        Backend->>FCM: Dispatch Alert (in Parent's Locale): "Bus Approaching (~1km)"
        FCM->>Parent: Notification with interactive actions: [I'm Ready] [2 Mins Late]
        Backend->>Centrifugo: Publish to parent:{userId}
        Centrifugo-->>Parent: Show approaching banner & ETA on map
    end

    alt Parent taps [I'm Ready]
        Parent->>Backend: POST /api/trips/{trip}/stops/{stop}/ack (ready)
        Backend->>Centrifugo: Publish to driver:{driverId}
        Centrifugo-->>Driver: Turn stop badge GREEN ("Ready")
    else Distance <= 100m (Arrival Zone) & Still Unacknowledged
        Backend->>FCM: Dispatch Urgent FCM: "Bus has arrived at your stop!"
        Backend->>Centrifugo: Publish StopUnresponsive to driver:{driverId}
        Centrifugo-->>Driver: Sound Alert + Open Fallback Contact Dialog
        Note over Driver: 1. Tap to Call (tel:+...)<br/>2. WhatsApp Pre-filled in Parent's Language<br/>3. Direct SMS<br/>4. High-Priority Push Siren
    end

    Driver->>Backend: Mark "Boarded" or "Absent"
    Backend->>Centrifugo: Advance queue to next nearest stop
```

---

## 5. Mobile Application Layered Architecture (Flutter)

```mermaid
flowchart TD
    subgraph PresentationLayer["Presentation Layer (Screens & Widgets)"]
        AuthView["PhoneOtpScreen"]
        DriverCockpit["DriverCockpitScreen (Map + Nearest Stop Focus)"]
        ChildCheckView["ChildCheckInspectionScreen (Rear QR/NFC Scan / Checklist)"]
        ParentTracking["ParentTrackingScreen (Map + Animated Bus Pin)"]
        StopPinning["PinStopScreen (OpenStreetMap Drop-Pin)"]
        FallbackModal["FallbackContactDialog (Call, WhatsApp, SMS, Siren)"]
        RoleDrawer["RoleSwitchDrawer (Driver Mode <-> Parent Mode)"]
    end

    subgraph StateLayer["State Management (flutter_bloc / Cubit)"]
        SessionCubit["SessionCubit (Auth & User Profile)"]
        RoleCubit["RoleModeCubit (Mode Switching)"]
        DriverTripBloc["DriverTripBloc (Active Trip State Machine)"]
        ParentTrackingBloc["ParentTrackingBloc (Live Tracking & ETAs)"]
    end

    subgraph CoreLayer["Core Services & Native Bridges"]
        BgLocation["BackgroundLocationService (flutter_background_service)"]
        CentrifugoClient["CentrifugoService (centrifuge SDK)"]
        PushHandler["NotificationService (FCM + Local Notifications)"]
        L10n["easy_localization (FR Default, EN Fallback, AR RTL with Cairo)"]
    end

    subgraph DataLayer["Data & Repository Layer"]
        DioClient["Dio HTTP Client (Bearer Token, Auto-Retry)"]
        SecureStorage["FlutterSecureStorage (Encrypted Token Storage)"]
        TripRepo["TripRepository"]
        UserRepo["UserRepository"]
    end

    PresentationLayer --> StateLayer
    StateLayer --> CoreLayer
    StateLayer --> DataLayer
    CoreLayer --> DataLayer
```

---

## 6. Phased Implementation Roadmap (Gantt Chart)

```mermaid
gantt
    title Ridin Implementation Roadmap
    dateFormat  YYYY-MM-DD
    section Phase 1: Database & Geo Foundation
    PostgreSQL + PostGIS & Extensions :p1_1, 2026-09-11, 1d
    58 Wilayas & 1541 Communes Seeders :p1_2, after p1_1, 1d
    Core Models, Spatie Teams & Violations Schema :p1_3, after p1_2, 1d

    section Phase 2: Centrifugo & Backend APIs
    Centrifugo Service & Broadcaster :p2_1, after p1_3, 1d
    Location Ingestion, PostGIS Geofence & Blackbox Logging :p2_2, after p2_1, 1d
    FCM Dual-Payload Alert & Delay Broadcasts :p2_3, after p2_2, 1d

    section Phase 3: Dashboards & Owner Tools
    Filament Super-Admin Panel :p3_1, after p2_3, 2d
    Livewire 4 + MaryUI Executive Command Center & Dispute Resolver :p3_2, after p3_1, 2d
    Chargily Pay & OCPay Gateways :p3_3, after p3_2, 1d

    section Phase 4: Flutter Mobile App
    Scaffolding, Theme & EasyLocalization :p4_1, after p3_3, 1d
    CentrifugoService & Foreground GPS Service :p4_2, after p4_1, 2d
    Driver Cockpit, Fallbacks & Child Check-Mate Inspection :p4_3, after p4_2, 2d
    Parent Live Tracking, Dynamic ETA & Stop Pinning :p4_4, after p4_3, 2d

    section Phase 5: Verification & End-to-End Testing
    Simulation Testing, Pint & Security Audits :p5_1, after p4_4, 2d
```
