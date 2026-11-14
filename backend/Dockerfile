FROM gcc:14-bookworm AS build
WORKDIR /src
COPY . .
RUN make test && make all

FROM debian:bookworm-slim
WORKDIR /app
COPY --from=build /src/build/flora-backend /app/flora-backend
EXPOSE 18080
ENTRYPOINT ["/app/flora-backend"]
