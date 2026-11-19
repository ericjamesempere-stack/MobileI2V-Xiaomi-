#include <MNN/Interpreter.hpp>
#include <MNN/Tensor.hpp>
#include <cmath>
#include <iostream>
#include <memory>
#include <string>
static bool fill(MNN::Interpreter* net, MNN::Session* session, const char* name, float value, int expected) {
    auto* t = net->getSessionInput(session, name);
    if (!t || t->elementSize() != expected || t->getType().code != halide_type_float ||
        t->getType().bits != 32) { std::cerr << "UNET_INPUT_MISMATCH " << name << "\n"; return false; }
    MNN::Tensor host(t, t->getDimensionType());
    for (int i = 0; i < expected; ++i) host.host<float>()[i] = value;
    return t->copyFromHostTensor(&host);
}
int main(int argc, char** argv) {
    if (argc != 2) return 2;
    std::unique_ptr<MNN::Interpreter> net(MNN::Interpreter::createFromFile(argv[1]));
    if (!net) return 3;
    MNN::ScheduleConfig cfg; cfg.type = MNN_FORWARD_CPU; cfg.numThread = 2;
    auto* session = net->createSession(cfg);
    if (!session) return 4;
    if (!fill(net.get(), session, "sample", 0.01f, 2*4*64*64) ||
        !fill(net.get(), session, "encoder_hidden_states", 0.01f, 2*77*768) ||
        !fill(net.get(), session, "timestep", 500.0f, 2)) return 5;
    const auto status = net->runSession(session);
    if (status != MNN::NO_ERROR) { std::cerr << "UNET_RUN_ERROR " << status << "\n"; return 6; }
    auto* t = net->getSessionOutput(session, "out_sample");
    if (!t || t->elementSize() != 2*4*64*64) return 7;
    MNN::Tensor host(t, t->getDimensionType());
    if (!t->copyToHostTensor(&host)) return 8;
    double sum = 0;
    for (int i = 0; i < t->elementSize(); ++i) {
        float v = host.host<float>()[i];
        if (!std::isfinite(v)) return 9;
        sum += std::abs(v);
    }
    if (!(sum > 0)) return 10;
    std::cout << "KARMA_UNET_REAL_INFERENCE_OK elements=" << t->elementSize()
              << " abs_sum=" << sum << "\n";
    net->releaseSession(session);
    return 0;
}
