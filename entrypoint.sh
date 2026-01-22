#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Function to log with timestamp
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# Start ComfyUI in the background
log_info "🚀 Starting ComfyUI in the background..."
python /ComfyUI/main.py --listen --use-sage-attention &
COMFYUI_PID=$!

# Wait for ComfyUI to be ready
log_info "⏳ Waiting for ComfyUI to be ready..."
max_wait=300  # Tăng lên 5 phút (300 giây)
wait_count=0
check_interval=2
start_time=$(date +%s)

while [ $wait_count -lt $max_wait ]; do
    # Kiểm tra xem process ComfyUI còn chạy không
    if ! kill -0 $COMFYUI_PID 2>/dev/null; then
        log_error "ComfyUI process đã dừng bất ngờ!"
        exit 1
    fi
    
    # Kiểm tra HTTP endpoint
    if curl -s --max-time 5 http://127.0.0.1:8188/ > /dev/null 2>&1; then
        end_time=$(date +%s)
        startup_time=$((end_time - start_time))
        log_info "✅ ComfyUI đã sẵn sàng sau ${startup_time} giây!"
        log_info "🎯 ComfyUI PID: $COMFYUI_PID"
        break
    fi
    
    # Log tiến trình mỗi 10 giây
    if [ $((wait_count % 10)) -eq 0 ]; then
        log_info "⏳ Đang chờ ComfyUI... ($wait_count/$max_wait giây)"
    fi
    
    sleep $check_interval
    wait_count=$((wait_count + check_interval))
done

# Kiểm tra timeout
if [ $wait_count -ge $max_wait ]; then
    log_error "ComfyUI không khởi động được sau $max_wait giây"
    log_error "Vui lòng kiểm tra logs ComfyUI để biết chi tiết"
    
    # Kill ComfyUI process nếu còn chạy
    if kill -0 $COMFYUI_PID 2>/dev/null; then
        log_info "🛑 Dừng ComfyUI process..."
        kill $COMFYUI_PID
    fi
    
    exit 1
fi

# Verify ComfyUI is actually responding
log_info "🔍 Kiểm tra ComfyUI API..."
if ! curl -s --max-time 10 http://127.0.0.1:8188/ > /dev/null 2>&1; then
    log_error "ComfyUI không phản hồi API requests"
    exit 1
fi

log_info "✅ ComfyUI API hoạt động bình thường"

# Start the handler in the foreground
log_info "🎬 Starting RunPod handler..."
exec python handler.py