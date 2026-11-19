#include <MNN/Interpreter.hpp>
#include <MNN/Tensor.hpp>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <memory>
#include <string>
static bool fill(MNN::Interpreter* net, MNN::Session* session, const char* name, float value, int expected) {
    auto* t = net->getSessionInput(session, name);
    if (!t || t->elementSize() != expected || t->getType().code != halide_type_float ||
        t->getType().bits != 32) { std::cerr << "UNET_INPUT_MISMATCH " << name
            << " present=" << (t != nullptr)
            << " count=" << (t ? t->elementSize() : -1)
            << " type_code=" << (t ? static_cast<int>(t->getType().code) : -1)
            << " type_bits=" << (t ? static_cast<int>(t->getType().bits) : -1)
            << " expected_count=" << expected << "\n"; return false; }
    MNN::Tensor host(t, t->getDimensionType());
    for (int i = 0; i < expected; ++i) host.host<float>()[i] = value;
    const bool ok = t->copyFromHostTensor(&host);
    if (!ok) std::cerr << "UNET_INPUT_COPY_FAILED " << name << "\n";
    return ok;
}
int main(int argc, char** argv) {
    if (argc != 2) return 2;
    std::unique_ptr<MNN::Interpreter> net(MNN::Interpreter::createFromFile(argv[1]));
    if (!net) return 3;
    MNN::ScheduleConfig cfg; cfg.type = MNN_FORWARD_CPU; cfg.numThread = 2;
    auto* session = net->createSession(cfg);
    if (!session) return 4;
    if (!fill(net.get(), session, "sample", 0.01f, 2*4*64*64) ||
        !fill(net.get(), session, "encoder_hidden_states", 0.01f, 2*77*768)) return 5;
    auto* timestep = net->getSessionInput(session, "timestep");
    if (!timestep || timestep->elementSize() != 2 || timestep->getType().code != halide_type_int ||
        timestep->getType().bits != 32) { std::cerr << "UNET_TIMESTEP_INT32_REQUIRED\n"; return 5; }
    MNN::Tensor timeHost(timestep, timestep->getDimensionType());
    timeHost.host<int32_t>()[0] = 500;
    timeHost.host<int32_t>()[1] = 500;
    if (!timestep->copyFromHostTensor(&timeHost)) return 5;
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
