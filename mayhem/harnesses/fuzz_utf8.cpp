// Normalizes arbitrary bytes to composed UTF-32 via Gosu::utf8_to_composed_utc4 (utf8proc).
#include <Gosu/Utility.hpp>
#include <cstdint>
#include <string_view>

extern "C" int LLVMFuzzerTestOneInput(const std::uint8_t* data, std::size_t size)
{
    std::u32string result =
        Gosu::utf8_to_composed_utc4(std::string_view(reinterpret_cast<const char*>(data), size));
    return result.size() == 0xdeadbeef ? 1 : 0;
}
