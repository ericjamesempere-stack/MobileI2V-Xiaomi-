#include <MNN/Interpreter.hpp>
#include <MNN/Tensor.hpp>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <memory>
int main(int argc, char** argv) {
    if (argc != 2) return 2;
    std::unique_ptr<MNN::Interpreter> net(MNN::Interpreter::createFromFile(argv[1]));
    if (!net) return 3;
    MNN::ScheduleConfig cfg; cfg.type = MNN_FORWARD_CPU; cfg.numThread = 2;
    auto* session = net->createSession(cfg);
    if (!session) return 4;
    auto* input = net->getSessionInput(session, "input_ids");
    if (!input || input->elementSize() != 154 || input->getType().code != halide_type_int ||
        input->getType().bits != 32) return 5;
    MNN::Tensor host(input, input->getDimensionType());
    auto* ids = host.host<int32_t>();
    for (int i = 0; i < 154; ++i) ids[i] = (i % 77 == 0) ? 49406 : 49407;
    if (!input->copyFromHostTensor(&host)) return 6;
    auto status = net->runSession(session);
    if (status != MNN::NO_ERROR) { std::cerr << "CLIP_RUN_ERROR " << status << "\n"; return 7; }
    auto* output = net->getSessionOutput(session, "last_hidden_state");
    if (!output || output->elementSize() != 2 * 77 * 768) return 8;
    MNN::Tensor out(output, output->getDimensionType());
    if (!output->copyToHostTensor(&out)) return 9;
    double sum = 0;
    for (int i = 0; i < out.elementSize(); ++i) {
        float v = out.host<float>()[i];
        if (!std::isfinite(v)) return 10;
        sum += std::abs(v);
    }
    if (!(sum > 0)) return 11;
    std::cout << "KARMA_CLIP_REAL_INFERENCE_OK elements=" << out.elementSize()
              << " abs_sum=" << sum << "\n";
    net->releaseSession(session);
    return 0;
}
