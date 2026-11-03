// Decodes arbitrary bytes with Gosu::load_image (stb_image) and re-encodes small results.
#include <Gosu/Bitmap.hpp>
#include <Gosu/Buffer.hpp>
#include <cstdint>
#include <cstring>
#include <exception>

extern "C" int LLVMFuzzerTestOneInput(const std::uint8_t* data, std::size_t size)
{
    if (size == 0) return -1;
    try {
        Gosu::Buffer buffer(size);
        std::memcpy(buffer.data(), data, size);
        Gosu::Bitmap bitmap = Gosu::load_image(buffer);

        if (bitmap.width() > 0 && bitmap.height() > 0 && bitmap.width() * bitmap.height() <= 65536) {
            bitmap.pixel(bitmap.width() - 1, bitmap.height() - 1);
            Gosu::save_image(bitmap, "png");
            Gosu::save_image(bitmap, "jpg");
            Gosu::save_image(bitmap, "bmp");
        }
    }
    catch (const std::exception&) {
        return -1;
    }
    return 0;
}
