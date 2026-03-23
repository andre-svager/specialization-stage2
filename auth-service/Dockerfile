# ---------- Builder ----------
FROM golang:1.22-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o auth-service

# ---------- Runtime ----------
FROM gcr.io/distroless/static:nonroot

WORKDIR /app

COPY --from=builder /app/auth-service /app/auth-service
COPY --from=builder /app/db/init.sql /app/db/init.sql

EXPOSE 8001

USER nonroot:nonroot

CMD ["/app/auth-service"]