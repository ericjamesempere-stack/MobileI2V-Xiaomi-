#include <MNN/Interpreter.hpp>
#include <MNN/Tensor.hpp>
#include <iostream>
#include <memory>
#include <string>
int main(int argc, char** argv) {
    if (argc != 2) { std::cerr << "usage: verify_mnn_graph_load graph.mnn\n"; return 2; }
    std::unique_ptr<MNN::Interpreter> net(MNN::Interpreter::createFromFile(argv[1]));
    if (!net) { std::cerr << "MNN_GRAPH_OPEN_FAILED " << argv[1] << "\n"; return 1; }
    MNN::ScheduleConfig cfg;
    cfg.type = MNN_FORWARD_CPU;
    cfg.numThread = 2;
    auto* session = net->createSession(cfg);
    if (!session) { std::cerr << "MNN_SESSION_CREATE_FAILED " << argv[1] << "\n"; return 1; }
    const auto inputs = net->getSessionInputAll(session);
    const auto outputs = net->getSessionOutputAll(session);
    if (inputs.empty() || outputs.empty()) { std::cerr << "MNN_GRAPH_MISSING_IO " << argv[1] << "\n"; return 1; }
    std::cout << "MNN_GRAPH_SESSION_OK " << argv[1] << " inputs=" << inputs.size() << " outputs=" << outputs.size() << "\n";
    for (const auto& kv : inputs) {
        std::cout << "INPUT " << kv.first << " dims=";
        for (int d : kv.second->shape()) std::cout << d << ",";
        std::cout << "\n";
    }
    for (const auto& kv : outputs) {
        std::cout << "OUTPUT " << kv.first << " dims=";
        for (int d : kv.second->shape()) std::cout << d << ",";
        std::cout << "\n";
    }
    net->releaseSession(session);
    return 0;
}
