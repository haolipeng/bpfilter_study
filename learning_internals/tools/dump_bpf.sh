#!/bin/bash
# dump_bpf.sh - 导出和分析 BPF 程序的工具脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否有 root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script requires root privileges"
        echo "Please run with sudo: sudo $0"
        exit 1
    fi
}

# 检查 bpftool 是否安装
check_bpftool() {
    if ! command -v bpftool &> /dev/null; then
        error "bpftool not found"
        echo "Please install bpftool:"
        echo "  Ubuntu/Debian: sudo apt install linux-tools-generic"
        echo "  Fedora/RHEL: sudo dnf install bpftool"
        exit 1
    fi
}

# 列出所有 BPF 程序
list_progs() {
    info "Listing all BPF programs..."
    echo ""
    bpftool prog show
    echo ""
}

# 列出所有 BPF maps
list_maps() {
    info "Listing all BPF maps..."
    echo ""
    bpftool map show
    echo ""
}

# 导出程序的翻译后指令（xlated）
dump_xlated() {
    local prog_id=$1
    local output_file=$2

    info "Dumping xlated instructions for program ID $prog_id"

    if [ -z "$output_file" ]; then
        bpftool prog dump xlated id "$prog_id"
    else
        bpftool prog dump xlated id "$prog_id" > "$output_file"
        success "Saved to $output_file"
    fi
}

# 导出程序的 JIT 编译后机器码
dump_jited() {
    local prog_id=$1
    local output_file=$2

    info "Dumping JIT compiled code for program ID $prog_id"

    if [ -z "$output_file" ]; then
        bpftool prog dump jited id "$prog_id"
    else
        bpftool prog dump jited id "$prog_id" > "$output_file"
        success "Saved to $output_file"
    fi
}

# 导出 BPF map 内容
dump_map() {
    local map_id=$1
    local output_file=$2

    info "Dumping map ID $map_id"

    if [ -z "$output_file" ]; then
        bpftool map dump id "$map_id"
    else
        bpftool map dump id "$map_id" > "$output_file"
        success "Saved to $output_file"
    fi
}

# 查找 bpfilter 相关的程序
find_bpfilter_progs() {
    info "Searching for bpfilter programs..."
    echo ""

    # 查找 XDP 程序
    info "XDP programs:"
    bpftool prog show type xdp 2>/dev/null || echo "  None found"
    echo ""

    # 查找 TC 程序
    info "TC programs:"
    bpftool prog show type sched_cls 2>/dev/null || echo "  None found"
    echo ""

    # 查找 Netfilter 程序
    info "Netfilter programs:"
    bpftool prog show type netfilter 2>/dev/null || echo "  None found"
    echo ""

    # 查找 Cgroup 程序
    info "Cgroup programs:"
    bpftool prog show type cgroup/skb 2>/dev/null || echo "  None found"
    echo ""
}

# 显示程序详细信息
show_prog_info() {
    local prog_id=$1

    info "Program details for ID $prog_id:"
    echo ""
    bpftool prog show id "$prog_id"
    echo ""

    info "Program instructions (first 50 lines):"
    echo ""
    bpftool prog dump xlated id "$prog_id" | head -50
    echo ""
}

# 导出完整报告
generate_report() {
    local output_dir=${1:-"bpf_report_$(date +%Y%m%d_%H%M%S)"}

    info "Generating BPF report in $output_dir"

    mkdir -p "$output_dir"

    # 程序列表
    bpftool prog show > "$output_dir/programs.txt"
    success "Saved program list"

    # Map 列表
    bpftool map show > "$output_dir/maps.txt"
    success "Saved map list"

    # 导出每个程序的详细信息
    local prog_ids=$(bpftool prog show -j | jq -r '.[].id' 2>/dev/null)

    if [ -n "$prog_ids" ]; then
        mkdir -p "$output_dir/programs"

        while IFS= read -r prog_id; do
            info "Exporting program $prog_id..."
            bpftool prog dump xlated id "$prog_id" > "$output_dir/programs/prog_${prog_id}_xlated.txt" 2>/dev/null || true
            bpftool prog dump jited id "$prog_id" > "$output_dir/programs/prog_${prog_id}_jited.txt" 2>/dev/null || true
        done <<< "$prog_ids"
    fi

    # 导出每个 map 的内容
    local map_ids=$(bpftool map show -j | jq -r '.[].id' 2>/dev/null)

    if [ -n "$map_ids" ]; then
        mkdir -p "$output_dir/maps"

        while IFS= read -r map_id; do
            info "Exporting map $map_id..."
            bpftool map dump id "$map_id" > "$output_dir/maps/map_${map_id}.txt" 2>/dev/null || true
        done <<< "$map_ids"
    fi

    success "Report generated in $output_dir"
}

# 显示帮助信息
show_help() {
    cat << EOF
BPF Program Dump Tool for bpfilter

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    list                List all BPF programs
    list-maps           List all BPF maps
    find                Find bpfilter-related programs
    xlated <id> [file]  Dump translated instructions
    jited <id> [file]   Dump JIT compiled code
    map <id> [file]     Dump map contents
    info <id>           Show program details
    report [dir]        Generate complete BPF report
    help                Show this help message

Examples:
    # List all BPF programs
    sudo $0 list

    # Find bpfilter programs
    sudo $0 find

    # Dump program 123's instructions
    sudo $0 xlated 123

    # Save to file
    sudo $0 xlated 123 prog123.txt

    # Dump JIT compiled code
    sudo $0 jited 123 prog123_jited.txt

    # Show program details
    sudo $0 info 123

    # Dump map 456
    sudo $0 map 456

    # Generate full report
    sudo $0 report

EOF
}

# 主函数
main() {
    check_root
    check_bpftool

    local command=${1:-help}
    shift || true

    case "$command" in
        list)
            list_progs
            ;;
        list-maps)
            list_maps
            ;;
        find)
            find_bpfilter_progs
            ;;
        xlated)
            if [ -z "$1" ]; then
                error "Program ID required"
                echo "Usage: $0 xlated <prog_id> [output_file]"
                exit 1
            fi
            dump_xlated "$1" "$2"
            ;;
        jited)
            if [ -z "$1" ]; then
                error "Program ID required"
                echo "Usage: $0 jited <prog_id> [output_file]"
                exit 1
            fi
            dump_jited "$1" "$2"
            ;;
        map)
            if [ -z "$1" ]; then
                error "Map ID required"
                echo "Usage: $0 map <map_id> [output_file]"
                exit 1
            fi
            dump_map "$1" "$2"
            ;;
        info)
            if [ -z "$1" ]; then
                error "Program ID required"
                echo "Usage: $0 info <prog_id>"
                exit 1
            fi
            show_prog_info "$1"
            ;;
        report)
            generate_report "$1"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
