// Feeds arbitrary markup (<b>, <c=rrggbb>, &entities;) through Gosu's MarkupParser.
#include "MarkupParser.hpp"
#include <cstdint>
#include <string>

extern "C" int LLVMFuzzerTestOneInput(const std::uint8_t* data, std::size_t size)
{
    if (size < 2) return -1;
    unsigned base_flags = data[0] & 0x7;
    bool split_words = data[1] & 1;
    std::string markup(reinterpret_cast<const char*>(data + 2), size - 2);

    std::size_t total = 0;
    Gosu::MarkupParser parser(base_flags, split_words,
                              [&total](std::vector<Gosu::FormattedString> parts) {
                                  for (const auto& part : parts) total += part.text.size();
                              });
    parser.parse(markup);
    return total == 0xdeadbeef ? 1 : 0;
}
