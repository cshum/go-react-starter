# build the front end
FROM node:26-alpine AS web
WORKDIR /app/web
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ ./
COPY testdata /app/testdata
RUN npm run build -- --outDir /app/server/dist

# build the binary with the UI embedded
FROM golang:1.27-alpine AS build
WORKDIR /src
COPY server/go.mod server/go.sum ./
COPY server/ ./
COPY --from=web /app/server/dist ./dist
RUN CGO_ENABLED=0 go build -tags embedui -trimpath -ldflags "-s -w -X main.version=docker" -o /out/app ./cmd/app

FROM gcr.io/distroless/static-debian12
COPY --from=build /out/app /app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app", "serve"]
