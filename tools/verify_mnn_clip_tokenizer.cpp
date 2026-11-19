#include <tokenizer/tokenizer.hpp>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <memory>
#include <string>
#include <vector>
#include <nlohmann/json.hpp>

int main(int argc, char** argv) {
    if (argc != 3) {
        std::cerr << "usage: verify_mnn_clip_tokenizer tokenizer.mtok clip_reference_vectors.json\n";
        return 2;
    }
    std::unique_ptr<MNN::Transformer::Tokenizer> tokenizer(
        MNN::Transformer::Tokenizer::createTokenizer(argv[1]));
    if (!tokenizer) return 3;
    std::ifstream file(argv[2]);
    if (!file) return 4;
    nlohmann::json reference;
    file >> reference;
    int checked = 0;
    for (auto it = reference.at("vectors").begin(); it != reference.at("vectors").end(); ++it) {
        const std::string prompt = it.key();
        auto ids = tokenizer->encode(prompt);
        if (ids.empty() || ids.front() != 49406) ids.insert(ids.begin(), 49406);
        if (ids.size() < 2 || ids.back() != 49407) ids.push_back(49407);
        if (ids.size() > 77) { ids.resize(77); ids.back() = 49407; }
        ids.resize(77, 49407);
        const auto expected = it.value().get<std::vector<int>>();
        if (ids.size() != expected.size()) return 5;
        for (size_t i = 0; i < ids.size(); ++i) {
            if (ids[i] != expected[i]) {
                std::cerr << "KARMA_CLIP_MTOK_PARITY_MISMATCH case=" << checked
                          << " index=" << i << " actual=" << ids[i]
                          << " expected=" << expected[i] << "\n";
                return 6;
            }
        }
        ++checked;
    }
    if (checked != 5) return 7;
    std::cout << "KARMA_CLIP_MTOK_PARITY_OK cases=" << checked << "\n";
    return 0;
}
