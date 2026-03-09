#pragma once

#include <chrono>
#include <fstream>
#include <mutex>
#include <sstream>
#include <string>

namespace qemu {
namespace control {

class Logger {
public:
    enum class Level { DEBUG, INFO, WARN, ERROR };

    static Logger& instance();

    void init(const std::string& log_path, Level min_level = Level::INFO);
    void set_min_level(Level level) { min_level_ = level; }

    void log(Level level, const std::string& msg);
    void info(const std::string& msg) { log(Level::INFO, msg); }
    void warn(const std::string& msg) { log(Level::WARN, msg); }
    void error(const std::string& msg) { log(Level::ERROR, msg); }

    static std::string level_str(Level level);

private:
    Logger() = default;
    std::string timestamp() const;
    void write(const std::string& line);

    std::mutex mtx_;
    std::ofstream file_;
    Level min_level_ = Level::INFO;
    bool to_stdout_ = true;
};

}  // namespace control
}  // namespace qemu
