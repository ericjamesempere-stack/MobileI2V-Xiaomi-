#include "karma_sd_scheduler.hpp"
#include <cassert>
#include <cmath>
#include <iostream>

int main() {
    const float latent[] = {0.5f, -0.25f, 1.0f};
    const float epsilon[] = {0.1f, 0.2f, -0.1f};
    float out[3] = {};
    assert(karma_sd::ddim_step(latent, epsilon, 0.5f, 1.0f, out, 3));
    for (int i = 0; i < 3; ++i) {
        float expected = (latent[i] - std::sqrt(0.5f) * epsilon[i]) / std::sqrt(0.5f);
        assert(std::abs(out[i] - expected) < 1e-5f);
    }
    assert(!karma_sd::ddim_step(latent, epsilon, 0.0f, 1.0f, out, 3));
    assert(!karma_sd::ddim_step(latent, epsilon, 0.8f, 0.7f, out, 3));
    assert(!karma_sd::ddim_step(latent, epsilon, 0.5f, 1.0f, out, 0));
    float bad[] = {NAN, 0.f, 0.f};
    assert(!karma_sd::ddim_step(bad, epsilon, 0.5f, 1.0f, out, 3));
    std::cout << "KARMA_MNN_DDIM_SCHEDULER_OK\n";
}
