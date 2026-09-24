# Pizza Order Tracker

A pizza ordering system built from three microservices and a web frontend.

## What's Inside

- **Order Service** (Port 3000): Receives pizza orders and coordinates with other services
- **Kitchen Service** (Port 3001): Checks availability and cooks pizzas
- **Delivery Service** (Port 3002): Assigns drivers for delivery
- **Frontend** (Port 8080): Simple web UI for ordering pizzas
- **OpenTelemetry Collector** (Port 4318): Receives telemetry from all of the above
  and forwards it to Dash0

## Architecture

```
┌─────────────┐
│   Browser   │
│  (Port 8080)│
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Order     │────▶│   Kitchen   │     │  Delivery   │
│  Service    │     │   Service   │     │   Service   │
│ (Port 3000) │     │ (Port 3001) │     │ (Port 3002) │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           ▼  OTLP
                 ┌───────────────────┐
                 │  OTel Collector   │──▶ Dash0
                 │    (Port 4318)    │
                 └───────────────────┘
```

## Running the App

Create your `.env` first — the Collector needs your Dash0 credentials, and
`docker compose up` fails with a message naming the missing variable if they
aren't there:

```bash
cp .env.template .env   # then fill in DASH0_AUTH_TOKEN and DASH0_ENDPOINT
docker compose up
```

Then open http://localhost:8080 and order a pizza.

To stop it:

```bash
docker compose down
```

## Seeing It in Dash0

Order a pizza, then open Dash0. Each order is one trace that starts in the
browser and runs through all three services:

```
POST /order                      order-service
├── POST /check-availability     kitchen-service
├── POST /cook                   kitchen-service
└── POST /assign-driver          delivery-service
```

Every log line the services write carries the `trace_id` of the request that
produced it, so you can pivot between a log and its trace in either direction.

If nothing shows up, the Collector tells you why:

```bash
docker compose logs -f otel-collector
```

It logs a line per batch it exports, and an explicit error if Dash0 rejects the
credentials.

## How the Instrumentation Works

No service imports an OpenTelemetry package or calls a tracing API. The
telemetry comes from two places:

**The three Node services** are instrumented by
[`@opentelemetry/auto-instrumentations-node`](https://www.npmjs.com/package/@opentelemetry/auto-instrumentations-node),
loaded via `NODE_OPTIONS` in `docker-compose.yml` before any application code
runs. It patches Express, the HTTP client, and Pino, which produces:

- a span per incoming request and per outgoing call
- `traceparent` headers on those outgoing calls, which is what stitches the
  three services into one trace
- `trace_id` / `span_id` on every Pino log line
- runtime and HTTP metrics

Configuration is entirely environment variables — `OTEL_SERVICE_NAME`,
`OTEL_EXPORTER_OTLP_ENDPOINT` and friends, set in `docker-compose.yml`.

**The frontend** uses the [Dash0 Web SDK](https://github.com/dash0hq/dash0-sdk-web)
loaded from a CDN in `index.html`, which adds page views, Core Web Vitals,
browser errors, and a span per `fetch` call. Its config is generated at container
start from `frontend/dash0.js.template`, so no credentials live in the image.

**The Collector** (`otel-collector/config.yaml`) is the only component holding
your Dash0 token. It also drops two kinds of noise before export: health-check
spans, and Express middleware spans. Remove `filter/drop-noise` from the
pipelines if you want to see them.

Because telemetry goes to the Collector rather than straight to Dash0, the
browser never receives a Dash0 token.


## Watching What Happens

The terminal shows all four services interleaved:

```
order-service    | {"level":30,...,"orderId":"PIZZA-123...","msg":"Order received"}
kitchen-service  | {"level":30,...,"orderId":"PIZZA-123...","msg":"Starting to cook"}
delivery-service | {"level":30,...,"orderId":"PIZZA-123...","msg":"Assigning driver"}
```

One service on its own:

```bash
docker compose logs -f kitchen-service
```

## Failure Modes You Can Switch On

### Slow Kitchen (Oven is Broken)
```bash
SLOW_KITCHEN=true docker compose up
```

Every pizza takes about five seconds longer to cook.

### No Drivers Available
```bash
NO_DRIVERS=true docker compose up
```

Delivery has nobody to assign, so orders fail.

## Services Overview

### Order Service
- Receives orders from the frontend
- Calls Kitchen Service to check availability and cook
- Calls Delivery Service to assign a driver
- Returns order confirmation

### Kitchen Service
- Checks if kitchen is available
- Simulates cooking time
- Can be configured to be slow (SLOW_KITCHEN=true)

### Delivery Service
- Finds available drivers
- Assigns driver to order
- Can be configured to have no drivers (NO_DRIVERS=true)

### Frontend
- Simple HTML form
- Sends orders to Order Service
- Displays confirmation

## Tech Stack

- **Node.js** - Runtime
- **Express** - Web framework
- **Axios** - HTTP client
- **Docker** - Containerization
- **OpenTelemetry** - Instrumentation, via auto-instrumentation and a Collector
- **Dash0** - Where the telemetry goes

## Ports

- `3000` - Order Service
- `3001` - Kitchen Service
- `3002` - Delivery Service
- `8080` - Frontend
- `4318` - OpenTelemetry Collector (OTLP/HTTP, used by the browser)
