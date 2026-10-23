#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include "input.hpp"
#include <cassert>
#include <limits>

static LRESULT CALLBACK later_subclass(HWND hwnd, UINT msg, WPARAM w, LPARAM l) {
    return DefWindowProcW(hwnd, msg, w, l);
}

int main() {
    using namespace mapteleport;
    MapView view{100, 200, 800, 900, 7, 1000, true};
    assert(accepts(view, 1000, 100, 200, true, true, true));
    assert(accepts(view, 1250, 799, 899, true, true, true));
    assert(!accepts(view, 1251, 400, 500, true, true, true));
    assert(!accepts(view, 999, 400, 500, true, true, true));
    assert(!accepts(view, 1000, 800, 500, true, true, true));
    assert(!accepts(view, 1000, 400, 900, true, true, true));
    assert(!accepts(view, 1000, 99, 500, true, true, true));
    assert(!accepts(view, 1000, 400, 199, true, true, true));
    for (int mask = 0; mask < 7; ++mask)
        assert(!accepts(view, 1000, 400, 500, mask & 1, mask & 2, mask & 4));
    view.enabled = false;
    assert(!accepts(view, 1000, 400, 500, true, true, true));
    view.enabled = true;
    assert(!accepts(view, 1000, std::numeric_limits<double>::quiet_NaN(), 500, true, true, true));

    HWND window = CreateWindowExW(0, L"STATIC", L"MapTeleport input lifecycle test",
        0, 0, 0, 100, 100, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
    assert(window);
    auto original = GetWindowLongPtrW(window, GWLP_WNDPROC);
    Input input;
    assert(input.install(window));
    auto ours = GetWindowLongPtrW(window, GWLP_WNDPROC);
    assert(ours != original);
    SetWindowLongPtrW(window, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(later_subclass));
    assert(!input.shutdown());
    assert(GetWindowLongPtrW(window, GWLP_WNDPROC) == reinterpret_cast<LONG_PTR>(later_subclass));
    SetWindowLongPtrW(window, GWLP_WNDPROC, ours);
    assert(input.shutdown());
    assert(GetWindowLongPtrW(window, GWLP_WNDPROC) == original);
    assert(input.shutdown());
    DestroyWindow(window);
}
