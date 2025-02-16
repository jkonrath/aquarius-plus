#include "file_io.h"
#include "esp.h"
#include <string.h>

int8_t opendir(const char *path) {
    esp_cmd(ESPCMD_OPENDIR);
    uint16_t len = strlen(path) + 1;
    esp_send_bytes(path, len);
    return (int8_t)esp_get_byte();
}
