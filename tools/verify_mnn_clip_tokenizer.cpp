#include <tokenizer/tokenizer.hpp>
#include <iostream>
#include <memory>
#include <string>
#include <vector>
int main(int argc, char** argv) {
    if (argc != 2) return 2;
    std::unique_ptr<MNN::Transformer::Tokenizer> tokenizer(
        MNN::Transformer::Tokenizer::createTokenizer(argv[1]));
    if (!tokenizer) return 3;
    const std::vector<std::string> prompts = {
        "", "a red apple", "Un été à Nice, très lumineux",
        "Moto, liberté et café !", [] {
            std::string s;
            for (int i = 0; i < 120; ++i) s += "hello ";
            return s;
        }()
    };
    for (const auto& prompt : prompts) {
        auto ids = tokenizer->encode(prompt);
        // Exact normalization used by KARMA's Android JNI.
        if (ids.empty() || ids.front() != 49406) ids.insert(ids.begin(), 49406);
        if (ids.size() < 2 || ids.back() != 49407) ids.push_back(49407);
        if (ids.size() > 77) { ids.resize(77); ids.back() = 49407; }
        ids.resize(77, 49407);
        for (size_t i = 0; i < ids.size(); ++i) {
            if (i) std::cout << ',';
            std::cout << ids[i];
        }
        std::cout << '\n';
    }
    return 0;
}
