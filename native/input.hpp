#pragma once
#include <windows.h>
#include <cmath>
#include <cstdint>
#include <mutex>
#include <optional>

namespace mapteleport {
struct MapView {
    double left{}, top{}, right{}, bottom{};
    uint64_t generation{}, refreshed{};
    bool enabled{};
};
struct Click {double x{}, y{}; uint64_t generation{};};
inline bool accepts(const MapView& view, uint64_t now, double x, double y,
                    bool foreground, bool control, bool shift) {
    return view.enabled && foreground && control && shift && now >= view.refreshed &&
        now - view.refreshed <= 250 && std::isfinite(x) && std::isfinite(y) &&
        view.right > view.left && view.bottom > view.top &&
        x >= view.left && x < view.right && y >= view.top && y < view.bottom;
}

// This captures Windows mouse messages before Unreal receives them. The map
// adapter must explicitly arm a fresh eligible view; default state passes input.
// Raw-input and overlay interactions still require qualification in the game.
class Input {
    inline static Input* instance{};
    std::mutex mutex;
    MapView view;
    std::optional<Click> pending;
    HWND window{};
    WNDPROC previous{};
    bool swallowed_down{};

    static LRESULT CALLBACK dispatch(HWND hwnd, UINT message, WPARAM w, LPARAM l) {
        return instance->receive(hwnd, message, w, l);
    }
    LRESULT receive(HWND hwnd, UINT message, WPARAM w, LPARAM l) {
        bool swallow = false;
        {
            std::lock_guard lock(mutex);
            if (message == WM_KILLFOCUS || message == WM_DESTROY ||
                (message == WM_ACTIVATEAPP && !w)) {
                view.enabled = false;
                pending.reset();
                swallowed_down = false;
            }
            if (message == WM_RBUTTONDOWN || message == WM_RBUTTONDBLCLK) {
                POINT point{static_cast<short>(LOWORD(l)), static_cast<short>(HIWORD(l))};
                if (ClientToScreen(hwnd, &point) && accepts(view, GetTickCount64(),
                    point.x, point.y, GetForegroundWindow() == hwnd,
                    (GetKeyState(VK_CONTROL) & 0x8000) != 0,
                    (GetKeyState(VK_SHIFT) & 0x8000) != 0)) {
                    if (!swallowed_down && !pending) {
                        pending = Click{double(point.x), double(point.y), view.generation};
                    }
                    swallowed_down = true;
                    swallow = true;
                }
            } else if (message == WM_RBUTTONUP && swallowed_down) {
                swallowed_down = false;
                swallow = true;
            }
        }
        return swallow ? 0 : CallWindowProcW(previous, hwnd, message, w, l);
    }
public:
    bool install(HWND target) {
        DWORD process{};
        GetWindowThreadProcessId(target, &process);
        if (!target || process != GetCurrentProcessId()) return false;
        if (window) return target == window;
        instance = this;
        previous = reinterpret_cast<WNDPROC>(GetWindowLongPtrW(target, GWLP_WNDPROC));
        if (!previous) {instance = nullptr; return false;}
        SetLastError(0);
        auto original = reinterpret_cast<WNDPROC>(SetWindowLongPtrW(target,
            GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(dispatch)));
        if (!original) {instance = nullptr; return false;}
        previous = original;
        window = target;
        return true;
    }
    void update(MapView next) {
        std::lock_guard lock(mutex);
        if (!next.enabled || next.generation != view.generation) pending.reset();
        view = next;
    }
    std::optional<Click> take() {
        std::lock_guard lock(mutex);
        auto result = pending;
        pending.reset();
        if (result && (!view.enabled || result->generation != view.generation ||
            GetTickCount64() - view.refreshed > 250)) result.reset();
        return result;
    }
    bool shutdown() {
        update({});
        if (!window) return true;
        if (!IsWindow(window)) {window = nullptr; return true;}
        // Do not remove another mod's later subclass from the chain.
        if (reinterpret_cast<WNDPROC>(GetWindowLongPtrW(window, GWLP_WNDPROC)) != dispatch)
            return false;
        SetLastError(0);
        if (!SetWindowLongPtrW(window, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(previous)))
            return false;
        window = nullptr;
        return true;
    }
};
}
