#include "logger.h"
#include <iostream>
#include <iomanip>

namespace qemu {
namespace control {

Logger& Logger::instance() {
    static Logger inst;
    return inst;
}

void Logger::init(const std::string& log_path, Level min_level) {
    std::lock_guard<std::mutex> lock(mtx_);
    min_level_ = min_level;
    if (!log_path.empty()) {
        file_.open(log_path, std::ios::app);
        to_stdout_ = !file_.is_open();
    } else {
        to_stdout_ = true;
    }
}

std::string Logger::timestamp() const {
    auto now = std::chrono::system_clock::now();
    auto t = std::chrono::system_clock::to_time_t(now);
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
        now.time_since_epoch()) % 1000;
    std::ostringstream oss;
    oss << std::put_time(std::localtime(&t), "%Y-%m-%d %H:%M:%S")
        << '.' << std::setfill('0') << std::setw(3) << ms.count();
    return oss.str();
}

std::string Logger::level_str(Level level) {
    switch (level) {
        case Level::DEBUG: return "DEBUG";
        case Level::INFO: return "INFO";
        case Level::WARN: return "WARN";
        case Level::ERROR: return "ERROR";
    }
    return "?";
}

void Logger::write(const std::string& line) {
    if (file_.is_open()) {
        file_ << line << std::endl;
        file_.flush();
    }
    if (to_stdout_) {
        std::cout << line << std::endl;
    }
}

void Logger::log(Level level, const std::string& msg) {
    if (level < min_level_) return;
    std::lock_guard<std::mutex> lock(mtx_);
    std::string line = "[" + timestamp() + "] [" + level_str(level) + "] " + msg;
    write(line);
}

}  // namespace control
}  // namespace qemu
