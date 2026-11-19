#include <MNN/Interpreter.hpp>
#include <MNN/Tensor.hpp>
#include <cmath>
#include <iostream>
#include <memory>
int main(int argc, char** argv) {
    if (argc != 2) return 2;
    std::unique_ptr<MNN::Interpreter> net(MNN::Interpreter::createFromFile(argv[1]));
    if (!net) return 3;
    MNN::ScheduleConfig cfg;
    cfg.type = MNN_FORWARD_CPU;
    cfg.numThread = 2;
    auto* session = net->createSession(cfg);
    if (!session) return 4;
    auto* latent = net->getSessionInput(session, "latent_sample");
    if (!latent || latent->elementSize() != 4*64*64 ||
        latent->getType().code != halide_type_float || latent->getType().bits != 32) {
        std::cerr << "VAE_LATENT_INPUT_MISMATCH\n";
        return 5;
    }
    MNN::Tensor input(latent, latent->getDimensionType());
    for (int i = 0; i < input.elementSize(); ++i)
        input.host<float>()[i] = 0.01f * std::sin(static_cast<float>(i) * 0.01f);
    if (!latent->copyFromHostTensor(&input)) return 6;
    auto status = net->runSession(session);
    if (status != MNN::NO_ERROR) {
        std::cerr << "VAE_RUN_ERROR " << status << "\n";
        return 7;
    }
    auto* output = net->getSessionOutput(session, "sample");
    if (!output || output->elementSize() != 3*512*512 ||
        output->getType().code != halide_type_float || output->getType().bits != 32) {
        std::cerr << "VAE_OUTPUT_MISMATCH\n";
        return 8;
    }
    MNN::Tensor host(output, output->getDimensionType());
    if (!output->copyToHostTensor(&host)) return 9;
    double sum = 0.0;
    for (int i = 0; i < host.elementSize(); ++i) {
        float v = host.host<float>()[i];
        if (!std::isfinite(v)) return 10;
        sum += std::abs(v);
    }
    if (!(sum > 0.0)) return 11;
    std::cout << "KARMA_VAE_REAL_INFERENCE_OK elements=" << host.elementSize()
              << " abs_sum=" << sum << "\n";
    net->releaseSession(session);
    return 0;
}
