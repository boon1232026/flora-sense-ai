#include "http_server.h"

#include "router.h"

#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define REQUEST_BUFFER_SIZE (4 * 1024 * 1024)
#define RESPONSE_BODY_SIZE 32768

static int content_length(const char *request)
{
    const char *header = strstr(request, "Content-Length:");
    if (!header) return 0;
    return atoi(header + 15);
}

static void extract_header(const char *request, const char *name, char *out, size_t size)
{
    if (!request || !name || !out || size == 0) return;
    out[0] = '\0';
    const char *line = strstr(request, name);
    if (!line) return;
    line += strlen(name);
    while (*line == ' ' || *line == '\t') ++line;
    size_t len = 0;
    while (line[len] && line[len] != '\r' && line[len] != '\n' && len + 1 < size) {
        out[len] = line[len];
        ++len;
    }
    out[len] = '\0';
}

static void send_binary_response(int client, const char *path)
{
    const char *filename = path + strlen("/uploads/");
    char disk_path[512];
    const char *root = getenv("FLORA_UPLOAD_DIR");
    root = (root && root[0]) ? root : "data/uploads";
    snprintf(disk_path, sizeof(disk_path), "%s/%s", root, filename);
    FILE *file = fopen(disk_path, "rb");
    if (!file) {
        static const char not_found[] = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
        send(client, not_found, strlen(not_found), 0);
        return;
    }
    const char *type = strstr(filename, ".png") ? "image/png" : strstr(filename, ".webp") ? "image/webp" : "image/jpeg";
    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    rewind(file);
    char header[512];
    int len = snprintf(header, sizeof(header), "HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Length: %ld\r\nCache-Control: public, max-age=3600\r\nConnection: close\r\n\r\n", type, size);
    send(client, header, (size_t)len, 0);
    char chunk[4096];
    size_t n;
    while ((n = fread(chunk, 1, sizeof(chunk), file)) > 0) send(client, chunk, n, 0);
    fclose(file);
}

static void send_response(int client, int status, const char *body)
{
    const char *reason = status == 200 ? "OK" :
                         status == 202 ? "Accepted" :
                         status == 204 ? "No Content" :
                         status == 400 ? "Bad Request" :
                         status == 401 ? "Unauthorized" :
                         status == 404 ? "Not Found" :
                         status == 422 ? "Unprocessable Content" : "Internal Server Error";
    size_t body_len = body ? strlen(body) : 0;
    char header[512];
    int header_len = snprintf(header, sizeof(header),
        "HTTP/1.1 %d %s\r\n"
        "Content-Type: application/json\r\n"
        "Content-Length: %zu\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "Access-Control-Allow-Headers: Content-Type, Authorization, Idempotency-Key\r\n"
        "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        "Connection: close\r\n\r\n",
        status, reason, body_len);
    send(client, header, (size_t)header_len, 0);
    if (body_len) send(client, body, body_len, 0);
}

static void handle_client(int client)
{
    char *request = calloc(REQUEST_BUFFER_SIZE + 1, 1);
    if (!request) {
        send_response(client, 500, "{\"error\":\"out_of_memory\"}");
        return;
    }
    ssize_t received = recv(client, request, REQUEST_BUFFER_SIZE, 0);
    if (received <= 0) {
        free(request);
        return;
    }
    request[received] = '\0';

    char method[16] = {0};
    char path[256] = {0};
    if (sscanf(request, "%15s %255s", method, path) != 2) {
        send_response(client, 400, "{\"error\":\"bad_request\"}");
        free(request);
        return;
    }
    if (strcmp(method, "OPTIONS") == 0) {
        send_response(client, 204, "");
        free(request);
        return;
    }

    char *body = strstr(request, "\r\n\r\n");
    body = body ? body + 4 : NULL;
    int expected = content_length(request);
    while (body && expected > 0 && (int)strlen(body) < expected &&
           (size_t)received < REQUEST_BUFFER_SIZE) {
        ssize_t more = recv(client, request + received, REQUEST_BUFFER_SIZE - (size_t)received, 0);
        if (more <= 0) break;
        received += more;
        request[received] = '\0';
    }

    char authorization[512];
    extract_header(request, "Authorization:", authorization, sizeof(authorization));
    if (strcmp(method, "GET") == 0 && strncmp(path, "/uploads/", strlen("/uploads/")) == 0 &&
        !strstr(path, "..")) {
        send_binary_response(client, path);
        free(request);
        return;
    }
    char response[RESPONSE_BODY_SIZE];
    int status = api_route_request(method, path, body, authorization, response, sizeof(response));
    send_response(client, status, response);
    free(request);
}

int http_server_run(int port)
{
    int server = socket(AF_INET, SOCK_STREAM, 0);
    if (server < 0) {
        perror("socket");
        return 1;
    }
    int enabled = 1;
    setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &enabled, sizeof(enabled));

    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    address.sin_port = htons((uint16_t)port);
    if (bind(server, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("bind");
        close(server);
        return 1;
    }
    if (listen(server, 16) < 0) {
        perror("listen");
        close(server);
        return 1;
    }
    printf("FLORA simulator backend listening on http://0.0.0.0:%d\n", port);
    fflush(stdout);
    while (true) {
        int client = accept(server, NULL, NULL);
        if (client >= 0) {
            handle_client(client);
            close(client);
        } else if (errno != EINTR) {
            perror("accept");
            break;
        }
    }
    close(server);
    return 0;
}
