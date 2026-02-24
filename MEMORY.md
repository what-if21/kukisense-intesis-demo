# Long-Term Memory

## E-ink Display Project (GDEP073E01)

### Hardware
- **Panel**: GDEP073E01 7.3" ACeP (Spectra 6) - 7 colors
- **Resolution**: 800x480 pixels
- **Controller**: Unknown (commands via SPI)
- **MCU**: ESP32-S3

### Critical Display Sequence
The working sample code reveals this exact order:

```
1. DTM (0x10)     → Send ALL pixel data (192000 bytes for 800x480)
2. PON (0x04)     → Power ON
3. BTST2 (0x06)   → 0x6F, 0x1F, 0x17, 0x49
4. DRF (0x12)     → 0x00 + 1ms delay
5. Wait BUSY      → Wait for completion
6. POF (0x02)     → 0x00 + wait BUSY
7. DSLP (0x07)    → 0xA5 (optional deep sleep)
```

**Key Insight**: Send data FIRST, then power on. This is opposite of some other e-paper panels.

### Color Encoding (4-bit per pixel, packed)
| Color | 4-bit Value | Packed Byte |
|-------|-------------|-------------|
| Black | 0x0 | 0x00 |
| White | 0x1 | 0x11 |
| Yellow| 0x2 | 0x22 |
| Red | 0x3 | 0x33 |
| Blue | 0x5 | 0x55 |
| Green | 0x6 | 0x66 |

Two pixels per byte: `(pixel1 << 4) | pixel2`

### SPI Notes
- CS must stay LOW during entire data transfer
- 10MHz clock works
- Mode 0 (CPOL=0, CPHA=0)

### Project Status
- [x] Basic initialization sequence
- [x] Test pattern implementation
- [ ] Hardware testing (pending ESP32-S3 connection)
- [ ] Full IAQ display with text
- [ ] BLE data reception
- [ ] Partial refresh optimization

### Learnings
- Sample code is the best reference - datasheet often incomplete
- Build errors from duplicate definitions are common when refactoring
- Always keep CS low for bulk data transfers
