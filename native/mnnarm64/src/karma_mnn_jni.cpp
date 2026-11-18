#include <jni.h>
#include "karma_sd_scheduler.hpp"
#include <vector>
#include <MNN/Interpreter.hpp>
#include <MNN/Tensor.hpp>
#include <memory>
#include <mutex>
#include <string>
#include <android/log.h>

namespace {
std::mutex g_lock;
std::unique_ptr<MNN::Interpreter> g_interpreter;
MNN::Session* g_session = nullptr;
std::string g_last_error;
void reset() {
    if (g_interpreter && g_session) g_interpreter->releaseSession(g_session);
    g_session = nullptr;
    g_interpreter.reset();
}
void error(const char* message) { g_last_error = message; }
}
extern "C" JNIEXPORT jboolean JNICALL
Java_com_mobilei2v_mnn_KarmaMnnBridge_nativeLoadGraph(JNIEnv* env, jclass, jstring path) {
    std::lock_guard<std::mutex> guard(g_lock);
    reset();
    if (!path) { error("null_model_path"); return JNI_FALSE; }
    const char* raw = env->GetStringUTFChars(path, nullptr);
    if (!raw) { error("invalid_model_path"); return JNI_FALSE; }
    std::string model_path(raw);
    env->ReleaseStringUTFChars(path, raw);
    if (model_path.empty()) { error("empty_model_path"); return JNI_FALSE; }
    g_interpreter.reset(MNN::Interpreter::createFromFile(model_path.c_str()));
    if (!g_interpreter) { error("mnn_graph_load_failed"); return JNI_FALSE; }
    MNN::ScheduleConfig config;
    config.type = MNN_FORWARD_CPU;
    config.numThread = 2;
    g_session = g_interpreter->createSession(config);
    if (!g_session) { reset(); error("mnn_session_creation_failed"); return JNI_FALSE; }
    g_last_error.clear();
    return JNI_TRUE;
}
extern "C" JNIEXPORT jboolean JNICALL
Java_com_mobilei2v_mnn_KarmaMnnBridge_nativeRunGraph(JNIEnv*, jclass) {
    std::lock_guard<std::mutex> guard(g_lock);
    if (!g_interpreter || !g_session) { error("mnn_graph_not_loaded"); return JNI_FALSE; }
    // This executes an MNN graph. It is NOT a Stable Diffusion sampler.
    if (g_interpreter->runSession(g_session) != MNN::NO_ERROR) {
        error("mnn_graph_execution_failed");
        return JNI_FALSE;
    }
    g_last_error.clear();
    return JNI_TRUE;
}
extern "C" JNIEXPORT jstring JNICALL
Java_com_mobilei2v_mnn_KarmaMnnBridge_nativeLastError(JNIEnv* env, jclass) {
    std::lock_guard<std::mutex> guard(g_lock);
    return env->NewStringUTF(g_last_error.c_str());
}
extern "C" JNIEXPORT void JNICALL
Java_com_mobilei2v_mnn_KarmaMnnBridge_nativeRelease(JNIEnv*, jclass) {
    std::lock_guard<std::mutex> guard(g_lock);
    reset();
}

extern "C" JNIEXPORT jfloatArray JNICALL
Java_com_mobilei2v_mnn_KarmaMnnBridge_nativeDdimStep(
    JNIEnv* env, jclass, jfloatArray latent, jfloatArray epsilon,
    jfloat alpha_t, jfloat alpha_prev) {
    if (!latent || !epsilon) return nullptr;
    const jsize count = env->GetArrayLength(latent);
    if (count <= 0 || count > 16777216 || env->GetArrayLength(epsilon) != count)
        return nullptr;
    std::vector<float> x(static_cast<size_t>(count));
    std::vector<float> e(static_cast<size_t>(count));
    std::vector<float> output(static_cast<size_t>(count));
    env->GetFloatArrayRegion(latent, 0, count, x.data());
    if (env->ExceptionCheck()) return nullptr;
    env->GetFloatArrayRegion(epsilon, 0, count, e.data());
    if (env->ExceptionCheck()) return nullptr;
    if (!karma_sd::ddim_step(x.data(), e.data(), alpha_t, alpha_prev, output.data(), output.size()))
        return nullptr;
    jfloatArray result = env->NewFloatArray(count);
    if (!result) return nullptr;
    env->SetFloatArrayRegion(result, 0, count, output.data());
    if (env->ExceptionCheck()) return nullptr;
    return result;
}
