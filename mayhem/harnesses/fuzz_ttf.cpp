// Parses and rasterizes text with an arbitrary TrueType font through Gosu::TrueTypeFont (stb_truetype).
#include "TrueTypeFont.hpp"
#include <cstdint>
#include <exception>
#include <memory>
#include <vector>

static std::uint64_t be16(const std::uint8_t* p) { return (p[0] << 8) | p[1]; }
static std::uint64_t be32(const std::uint8_t* p)
{
    return (std::uint64_t(p[0]) << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
}

// stb_truetype trusts the sfnt table directory and does no bounds checks on it, and
// TrueTypeFont(const unsigned char*, ...) takes no size. Reject input whose directory (or any
// table it lists) does not fit in `size`, so the fuzzer spends its time on the font parsing itself.
static bool font_directory_fits(const std::uint8_t* d, std::uint64_t size)
{
    std::uint64_t start = 0;
    if (size >= 4 && d[0] == 't' && d[1] == 't' && d[2] == 'c' && d[3] == 'f') {
        if (size < 16) return false;
        std::uint64_t version = be32(d + 4);
        if ((version != 0x00010000 && version != 0x00020000) || be32(d + 8) < 1) return false;
        start = be32(d + 12);
    }
    else if (!(size >= 4 && ((d[0] == '1' && d[1] == 0 && d[2] == 0 && d[3] == 0) ||
                             (d[0] == 0 && d[1] == 1 && d[2] == 0 && d[3] == 0) ||
                             (d[0] == 't' && d[1] == 'y' && d[2] == 'p' && d[3] == '1') ||
                             (d[0] == 'O' && d[1] == 'T' && d[2] == 'T' && d[3] == 'O') ||
                             (d[0] == 't' && d[1] == 'r' && d[2] == 'u' && d[3] == 'e')))) {
        return false;
    }

    if (start + 12 > size) return false;
    std::uint64_t num_tables = be16(d + start + 4);
    std::uint64_t dir_end = start + 12 + 16 * num_tables;
    if (dir_end > size) return false;
    for (std::uint64_t i = 0; i < num_tables; ++i) {
        const std::uint8_t* entry = d + start + 12 + 16 * i;
        std::uint64_t offset = be32(entry + 8);
        std::uint64_t length = be32(entry + 12);
        if (offset > size || length > size - offset) return false;
    }
    return true;
}

extern "C" int LLVMFuzzerTestOneInput(const std::uint8_t* data, std::size_t size)
{
    if (size < 12) return -1;

    // Exact-size heap copy so ASan sees any read past the end of the font data.
    std::vector<std::uint8_t> font(data, data + size);
    if (!font_directory_fits(font.data(), size)) return -1;

    try {
        Gosu::TrueTypeFont ttf(font.data(), nullptr);
        Gosu::Bitmap bitmap(64, 32, Gosu::Color::NONE);
        ttf.draw_text(U"Hello, W\u00f6rld! gjpqy", 16, &bitmap, 1, 1, Gosu::Color::WHITE);
    }
    catch (const std::exception&) {
        return -1;
    }
    return 0;
}
