// Decodes arbitrary bytes with Gosu's SDL_sound-based AudioFile (wav/aiff/au/voc/flac/mp3/ogg/mod...).
#include <Gosu/Buffer.hpp>
#include "AudioFile.hpp"
#include <cstdint>
#include <cstring>
#include <exception>

extern "C" int LLVMFuzzerTestOneInput(const std::uint8_t* data, std::size_t size)
{
    if (size == 0) return -1;
    try {
        Gosu::Buffer buffer(size);
        std::memcpy(buffer.data(), data, size);
        Gosu::AudioFile file(std::move(buffer));

        file.sample_rate();
        char chunk[4096];
        for (int i = 0; i < 64; ++i) {
            if (file.read_data(chunk, sizeof chunk) == 0) break;
        }
        file.rewind();
        file.read_data(chunk, sizeof chunk);
    }
    catch (const std::exception&) {
        return -1;
    }
    return 0;
}
