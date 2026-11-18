#pragma once
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace karma_sd {
// DDIM epsilon-prediction update (eta=0). The caller must provide real UNet
// epsilon tensors and alpha_cumprod values matching the converted model scheduler.
// No neural inference occurs in this function.
inline bool ddim_step(const float* latent, const float* epsilon,
                      float alpha_t, float alpha_prev,
                      float* result, size_t count) {
    if (!latent || !epsilon || !result || count == 0 || count > 16777216 ||
        !std::isfinite(alpha_t) || !std::isfinite(alpha_prev) ||
        alpha_t <= 0.f || alpha_t > 1.f ||
        alpha_prev <= 0.f || alpha_prev > 1.f || alpha_prev < alpha_t)
        return false;
    const float inv_sqrt_t = 1.f / std::sqrt(alpha_t);
    const float noise_scale_t = std::sqrt(1.f - alpha_t);
    const float prev_signal = std::sqrt(alpha_prev);
    const float prev_noise = std::sqrt(1.f - alpha_prev);
    for (size_t i = 0; i < count; ++i) {
        if (!std::isfinite(latent[i]) || !std::isfinite(epsilon[i])) return false;
        const float x0 = (latent[i] - noise_scale_t * epsilon[i]) * inv_sqrt_t;
        const float next = prev_signal * x0 + prev_noise * epsilon[i];
        if (!std::isfinite(next)) return false;
        result[i] = next;
    }
    return true;
}
}
