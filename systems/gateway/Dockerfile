FROM golang:1.24-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -tags fts5 -o cadence-server .

FROM alpine:3.21
RUN apk add --no-cache ca-certificates
COPY --from=build /app/cadence-server /usr/local/bin/
CMD ["cadence-server"]
