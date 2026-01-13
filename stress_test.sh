#!/bin/bash

# 终端压力测试脚本
# 使用方法: ./stress_test.sh [模式]
# 模式: fast(快速) | info(信息) | color(彩色) | heavy(高强度)
# 按 Ctrl+C 停止

MODE=${1:-fast}

case $MODE in
  fast)
    # 快速刷新计数器（0.01秒间隔）
    echo "快速刷新模式 - 按 Ctrl+C 停止"
    i=0
    while true; do
      clear
      echo "刷新次数: $i"
      echo "时间: $(date +%H:%M:%S.%N)"
      ((i++))
      sleep 0.01
    done
    ;;
  
  info)
    # 显示系统信息（0.1秒间隔）
    echo "系统信息刷新模式 - 按 Ctrl+C 停止"
    while true; do
      clear
      echo "========== 系统信息 =========="
      date
      echo ""
      echo "CPU 使用率:"
      top -l 1 | grep "CPU usage" | head -1
      echo ""
      echo "内存使用:"
      vm_stat | head -5
      echo ""
      echo "进程数: $(ps aux | wc -l)"
      sleep 0.1
    done
    ;;
  
  color)
    # 彩色输出压力测试
    echo "彩色输出模式 - 按 Ctrl+C 停止"
    while true; do
      clear
      for i in {1..50}; do
        color=$((RANDOM % 8 + 30))
        echo -e "\033[${color}m压力测试 $i - $(date +%H:%M:%S.%N)\033[0m"
      done
      sleep 0.1
    done
    ;;
  
  heavy)
    # 高强度压力测试（大量输出）
    echo "高强度模式 - 按 Ctrl+C 停止"
    i=0
    while true; do
      for j in {1..1000}; do
        echo "压力测试 [$i] - 行 $j - $(date +%H:%M:%S.%N)"
      done
      ((i++))
      sleep 0.1
    done
    ;;
  
  *)
    echo "使用方法: $0 [fast|info|color|heavy]"
    echo ""
    echo "模式说明:"
    echo "  fast   - 快速刷新计数器（推荐用于基本测试）"
    echo "  info   - 显示系统信息刷新"
    echo "  color  - 彩色输出压力测试"
    echo "  heavy  - 高强度大量输出（可能影响性能）"
    exit 1
    ;;
esac
