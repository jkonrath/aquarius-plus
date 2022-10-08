#include "aq_keyb.h"
#include "aq_keyb_defs.h"
#include "fpga.h"
#include "flash.h"
#include "screen.h"
#include <esp_system.h>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

static const char *TAG = "keyboard";

static uint8_t keyb_matrix[8] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

static inline void _aqkey_up(int key) {
    keyb_matrix[key / 6] |= (1 << (key % 6));
}
static inline void _aqkey_down(int key) {
    keyb_matrix[key / 6] &= ~(1 << (key % 6));
}

static inline void aqkey_down(int key, bool shift) {
    _aqkey_down(key);
    if (shift) {
        _aqkey_down(KEY_SHIFT);
    } else {
        _aqkey_up(KEY_SHIFT);
    }
}

static bool verify_sysrom(void) {
    bool ok = true;

    fpga_bus_acquire();
    fpga_save_banks();

    screen_save();
    screen_show_msg("Verifying system ROM");
    vTaskDelay(pdMS_TO_TICKS(1000));

    extern const uint8_t rom_image_start[] asm("_binary_aquarius_s2_rom_start");
    extern const uint8_t rom_image_end[] asm("_binary_aquarius_s2_rom_end");

    ESP_LOGI(TAG, "* Verifying boot ROM *");
    {
        uint8_t saved_bank = fpga_io_read(IO_BANK0);

        unsigned       addr = 0;
        const uint8_t *p    = rom_image_start;
        while (p != rom_image_end) {
            fpga_set_bank(0, addr >> 14);
            uint8_t flash_val = fpga_mem_read(addr & 0x3FFF);

            if (true) { // flash_val != *p) {
                char str[50];
                snprintf(str, sizeof(str), "Verify error @ $%05X   (%02X != %02X)", addr, flash_val, *p);
                screen_show_msg(str);

                ESP_LOGE(TAG, "Verify error @ 0x%X   (%02X != %02X)", addr, flash_val, *p);
                ok = false;
            }
            p++;
            addr++;
        }
        fpga_io_write(IO_BANK0, saved_bank);
    }
    ESP_LOGI(TAG, "Done.");

    if (ok) {
        screen_show_msg("Verifying system ROM OK!");
    } else {
        vTaskDelay(pdMS_TO_TICKS(2000));
        screen_show_msg("Verifying system ROM failed!");
    }
    vTaskDelay(pdMS_TO_TICKS(2000));

    screen_restore();
    fpga_restore_banks();
    fpga_bus_release();

    return ok;
}

static void flash_sysrom(void) {
    fpga_bus_acquire();

    screen_save();
    screen_show_msg("Programming system ROM");

    extern const uint8_t rom_image_start[] asm("_binary_aquarius_s2_rom_start");
    extern const uint8_t rom_image_end[] asm("_binary_aquarius_s2_rom_end");

    ESP_LOGI(TAG, "* Programming system ROM *");

    bool led = false;

    {
        flash_prepare();

        unsigned       addr = 0;
        const uint8_t *p    = rom_image_start;
        while (p != rom_image_end) {
            if ((addr & 4095) == 0) {
                flash_erase_4kb_sector(addr);
            }

            if ((addr & 1023) == 0) {
                gpio_set_level(IOPIN_LED, led ? 1 : 0);
                led = !led;

                char str[40];
                snprintf(str, sizeof(str), "Programming system ROM @ $%05X", addr);
                screen_show_msg(str);

                ESP_LOGI(TAG, "Programming @ 0x%X", addr);
            }

            flash_program(addr, *p);

            p++;
            addr++;
        }
        flash_finish();
    }
    ESP_LOGI(TAG, "Done.");
    gpio_set_level(IOPIN_LED, 1);

    screen_show_msg("Programming system ROM done.");
    vTaskDelay(pdMS_TO_TICKS(1000));

    screen_restore();
    fpga_bus_release();
}

void keyboard_scancode(unsigned scancode, bool keydown) {
    // if (keydown) {
    //     ESP_LOGI(TAG, "Key pressed:  %02X", scancode);
    // } else {
    //     ESP_LOGI(TAG, "Key released: %02X", scancode);
    // }

    // Hand controller emulation
    // handcontroller(scancode, keydown);

    // Keep track of pressed modifier keys
    static uint16_t modifiers = 0;
    if (scancode == SDL_SCANCODE_LSHIFT)
        modifiers = (modifiers & ~KMOD_LSHIFT) | (keydown ? KMOD_LSHIFT : 0);
    if (scancode == SDL_SCANCODE_RSHIFT)
        modifiers = (modifiers & ~KMOD_RSHIFT) | (keydown ? KMOD_RSHIFT : 0);
    if (scancode == SDL_SCANCODE_LCTRL)
        modifiers = (modifiers & ~KMOD_LCTRL) | (keydown ? KMOD_LCTRL : 0);
    if (scancode == SDL_SCANCODE_RCTRL)
        modifiers = (modifiers & ~KMOD_RCTRL) | (keydown ? KMOD_RCTRL : 0);
    if (scancode == SDL_SCANCODE_LALT)
        modifiers = (modifiers & ~KMOD_LALT) | (keydown ? KMOD_LALT : 0);
    if (scancode == SDL_SCANCODE_RALT)
        modifiers = (modifiers & ~KMOD_RALT) | (keydown ? KMOD_RALT : 0);
    if (scancode == SDL_SCANCODE_LGUI)
        modifiers = (modifiers & ~KMOD_LGUI) | (keydown ? KMOD_LGUI : 0);
    if (scancode == SDL_SCANCODE_RGUI)
        modifiers = (modifiers & ~KMOD_RGUI) | (keydown ? KMOD_RGUI : 0);

    bool ctrl_pressed  = (modifiers & (KMOD_LCTRL | KMOD_RCTRL)) != 0;
    bool alt_pressed   = (modifiers & (KMOD_LALT | KMOD_RALT)) != 0;
    bool shift_pressed = (modifiers & (KMOD_LSHIFT | KMOD_RSHIFT)) != 0;
    bool gui_pressed   = (modifiers & (KMOD_LGUI | KMOD_RGUI)) != 0;

    // Keep track of pressed keys
    static uint8_t pressed_keys[8] = {0};
    if (scancode < 64) {
        if (keydown) {
            pressed_keys[scancode / 8] |= 1 << (scancode & 7);
        } else {
            pressed_keys[scancode / 8] &= ~(1 << (scancode & 7));
        }
    }

    if (keydown && scancode == SDL_SCANCODE_F1) {
        fpga_bus_acquire();
        fpga_mem_write(0x3000 + 40, fpga_mem_read(0x3000 + 40) + 1);
        fpga_bus_release();
    }

    if (keydown && scancode == SDL_SCANCODE_F4) {
        fpga_bus_acquire();
        for (int i = IO_BANK0; i <= IO_BANK3; i++) {
            ESP_LOGI(TAG, "IO %02X: %02X", i, fpga_io_read(i));
        }
        fpga_bus_release();
    }

    enum {
        UP    = (1 << 0),
        DOWN  = (1 << 1),
        LEFT  = (1 << 2),
        RIGHT = (1 << 3),
        K1    = (1 << 4),
        K2    = (1 << 5),
        K3    = (1 << 6),
        K4    = (1 << 7),
        K5    = (1 << 8),
        K6    = (1 << 9),
    };

    // Clear keyboard state
    for (int i = 0; i < 8; i++) {
        keyb_matrix[i] = 0xFF;
    }

    // Set keyboard state based on currently pressed keys
    if (ctrl_pressed)
        _aqkey_down(KEY_CTRL);
    if (shift_pressed)
        _aqkey_down(KEY_SHIFT);

    for (int i = 0; i < 64; i++) {
        if (pressed_keys[i / 8] & (1 << (i & 7))) {
            switch (i) {
                case SDL_SCANCODE_ESCAPE:
                    if (ctrl_pressed && shift_pressed && alt_pressed && gui_pressed) {
                        // CTRL-SHIFT-ALT-GUI -> reprogram flash
                        flash_sysrom();
                        if (!verify_sysrom()) {
                            for (int i = 0; i < 5; i++) {
                                gpio_set_level(IOPIN_LED, 0);
                                vTaskDelay(pdMS_TO_TICKS(200));
                                gpio_set_level(IOPIN_LED, 1);
                                vTaskDelay(pdMS_TO_TICKS(200));
                            }
                        } else {
                            esp_restart();
                        }

                    } else if (ctrl_pressed && shift_pressed) {
                        // CTRL-SHIFT-ESCAPE -> reset ESP32 (somewhat equivalent to power cycle)
                        esp_restart();

                    } else if (ctrl_pressed) {
                        // CTRL-ESCAPE -> reset
                        fpga_reset_req();
                    } else {
                        // ESCAPE -> CTRL-C
                        _aqkey_down(KEY_CTRL);
                        _aqkey_down(KEY_C);
                    }
                    break;

                case SDL_SCANCODE_RETURN:
                    aqkey_down(KEY_RETURN, shift_pressed);
                    break;

                case SDL_SCANCODE_1: aqkey_down(KEY_1, shift_pressed); break;
                case SDL_SCANCODE_2:
                    if (!shift_pressed)
                        aqkey_down(KEY_2, false);
                    else
                        aqkey_down(KEY_SEMICOLON, true);
                    break;
                case SDL_SCANCODE_3: aqkey_down(KEY_3, shift_pressed); break;
                case SDL_SCANCODE_4: aqkey_down(KEY_4, shift_pressed); break;
                case SDL_SCANCODE_5: aqkey_down(KEY_5, shift_pressed); break;
                case SDL_SCANCODE_6:
                    if (!shift_pressed)
                        aqkey_down(KEY_6, false);
                    else
                        aqkey_down(KEY_SLASH, true);
                    break;
                case SDL_SCANCODE_7:
                    if (!shift_pressed)
                        aqkey_down(KEY_7, false);
                    else
                        aqkey_down(KEY_6, true);
                    break;
                case SDL_SCANCODE_8:
                    if (!shift_pressed)
                        aqkey_down(KEY_8, false);
                    else
                        aqkey_down(KEY_COLON, true);
                    break;
                case SDL_SCANCODE_9:
                    if (!shift_pressed)
                        aqkey_down(KEY_9, false);
                    else
                        aqkey_down(KEY_8, true);
                    break;
                case SDL_SCANCODE_0:
                    if (!shift_pressed)
                        aqkey_down(KEY_0, false);
                    else
                        aqkey_down(KEY_9, true);
                    break;
                case SDL_SCANCODE_MINUS: aqkey_down(KEY_MINUS, shift_pressed); break;
                case SDL_SCANCODE_EQUALS: aqkey_down(KEY_EQUALS, shift_pressed); break;
                case SDL_SCANCODE_BACKSPACE: aqkey_down(KEY_BACKSPACE, false); break;

                case SDL_SCANCODE_Q: aqkey_down(KEY_Q, shift_pressed); break;
                case SDL_SCANCODE_W: aqkey_down(KEY_W, shift_pressed); break;
                case SDL_SCANCODE_E: aqkey_down(KEY_E, shift_pressed); break;
                case SDL_SCANCODE_R: aqkey_down(KEY_R, shift_pressed); break;
                case SDL_SCANCODE_T: aqkey_down(KEY_T, shift_pressed); break;
                case SDL_SCANCODE_Y: aqkey_down(KEY_Y, shift_pressed); break;
                case SDL_SCANCODE_U: aqkey_down(KEY_U, shift_pressed); break;
                case SDL_SCANCODE_I: aqkey_down(KEY_I, shift_pressed); break;
                case SDL_SCANCODE_O: aqkey_down(KEY_O, shift_pressed); break;
                case SDL_SCANCODE_P: aqkey_down(KEY_P, shift_pressed); break;

                case SDL_SCANCODE_A: aqkey_down(KEY_A, shift_pressed); break;
                case SDL_SCANCODE_S: aqkey_down(KEY_S, shift_pressed); break;
                case SDL_SCANCODE_D: aqkey_down(KEY_D, shift_pressed); break;
                case SDL_SCANCODE_F: aqkey_down(KEY_F, shift_pressed); break;
                case SDL_SCANCODE_G: aqkey_down(KEY_G, shift_pressed); break;
                case SDL_SCANCODE_H: aqkey_down(KEY_H, shift_pressed); break;
                case SDL_SCANCODE_J: aqkey_down(KEY_J, shift_pressed); break;
                case SDL_SCANCODE_K: aqkey_down(KEY_K, shift_pressed); break;
                case SDL_SCANCODE_L: aqkey_down(KEY_L, shift_pressed); break;
                case SDL_SCANCODE_SEMICOLON:
                    if (!shift_pressed)
                        aqkey_down(KEY_SEMICOLON, false);
                    else
                        aqkey_down(KEY_COLON, false);
                    break;
                case SDL_SCANCODE_APOSTROPHE:
                    if (!shift_pressed)
                        aqkey_down(KEY_7, true);
                    else
                        aqkey_down(KEY_2, true);
                    break;
                case SDL_SCANCODE_BACKSLASH:
                    if (!shift_pressed)
                        aqkey_down(KEY_BACKSPACE, true);
                    break;

                case SDL_SCANCODE_Z: aqkey_down(KEY_Z, shift_pressed); break;
                case SDL_SCANCODE_X: aqkey_down(KEY_X, shift_pressed); break;
                case SDL_SCANCODE_C: aqkey_down(KEY_C, shift_pressed); break;
                case SDL_SCANCODE_V: aqkey_down(KEY_V, shift_pressed); break;
                case SDL_SCANCODE_B: aqkey_down(KEY_B, shift_pressed); break;
                case SDL_SCANCODE_N: aqkey_down(KEY_N, shift_pressed); break;
                case SDL_SCANCODE_M: aqkey_down(KEY_M, shift_pressed); break;
                case SDL_SCANCODE_COMMA: aqkey_down(KEY_COMMA, shift_pressed); break;
                case SDL_SCANCODE_PERIOD: aqkey_down(KEY_PERIOD, shift_pressed); break;
                case SDL_SCANCODE_SLASH:
                    if (!shift_pressed)
                        aqkey_down(KEY_SLASH, false);
                    else
                        aqkey_down(KEY_0, true);
                    break;

                case SDL_SCANCODE_SPACE:
                    aqkey_down(KEY_SPACE, shift_pressed);
                    break;
            }
        }
    }
}

void keyboard_update_matrix(void) {
    static uint8_t prev_matrix[8];
    if (memcmp(prev_matrix, keyb_matrix, 8) == 0) {
        return;
    }

    // ESP_LOG_BUFFER_HEX(TAG, keyb_matrix, 8);
    fpga_update_keyb_matrix(keyb_matrix);

    memcpy(prev_matrix, keyb_matrix, 8);
}