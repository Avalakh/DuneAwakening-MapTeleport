#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <bcrypt.h>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <memory>
#include <string>
#include <vector>
#include <LuaMadeSimple/LuaMadeSimple.hpp>
#include "input.hpp"

// Public headers: UE4SS f58e8f840243d60e29d46e9bb2fcc2919ef6f926.
// No Unreal class layouts or vtable offsets are reproduced here.
using Lua = RC::LuaMadeSimple::Lua;
using ProcessEvent = void (*)(void*, void*, void*);
using PropertySize = uint16_t& (*)(void*);
using ReturnOffset = uint16_t& (*)(void*);
static ProcessEvent process_event;
static PropertySize property_size;
static ReturnOffset return_offset;
static mapteleport::Input input;

static int arm(const Lua& lua) {
    auto window = reinterpret_cast<HWND>(static_cast<uintptr_t>(lua.get_integer(1)));
    mapteleport::MapView view;
    // LuaMadeSimple getters consume their argument from the stack.
    view.generation = static_cast<uint64_t>(lua.get_integer(1));
    view.left = lua.get_number(1);
    view.top = lua.get_number(1);
    view.right = lua.get_number(1);
    view.bottom = lua.get_number(1);
    view.refreshed = GetTickCount64();
    view.enabled = true;
    bool ok = input.install(window);
    input.update(ok ? view : mapteleport::MapView{});
    lua.set_bool(ok);
    return 1;
}

static int disarm(const Lua&) {input.update({}); return 0;}
static int shutdown(const Lua& lua) {lua.set_bool(input.shutdown()); return 1;}
static int poll(const Lua& lua) {
    auto click = input.take();
    lua.set_bool(click.has_value());
    if (!click) return 1;
    lua.set_number(click->x);
    lua.set_number(click->y);
    lua.set_integer(static_cast<int64_t>(click->generation));
    return 4;
}

static int game_window(const Lua& lua) {
    HWND found{};
    EnumWindows([](HWND window, LPARAM output) -> BOOL {
        DWORD process{};
        GetWindowThreadProcessId(window, &process);
        if (process != GetCurrentProcessId() || !IsWindowVisible(window) ||
            GetWindow(window, GW_OWNER)) return TRUE;
        wchar_t name[128]{};
        GetClassNameW(window, name, 128);
        if (std::wstring_view(name) != L"UnrealWindow") return TRUE;
        *reinterpret_cast<HWND*>(output) = window;
        return FALSE;
    }, reinterpret_cast<LPARAM>(&found));
    lua.set_integer(static_cast<int64_t>(reinterpret_cast<uintptr_t>(found)));
    return 1;
}

static bool qualified_runtime(HMODULE module) {
    wchar_t path[32768];
    if (!GetModuleFileNameW(module, path, 32768)) return false;
    HANDLE file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE |
        FILE_SHARE_DELETE, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return false;
    BCRYPT_ALG_HANDLE algorithm{};
    BCRYPT_HASH_HANDLE hash{};
    bool ok = BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) >= 0;
    if (ok) ok = BCryptCreateHash(algorithm, &hash, nullptr, 0, nullptr, 0, 0) >= 0;
    std::array<unsigned char, 65536> buffer{};
    DWORD count{};
    while (ok) {
        if (!ReadFile(file, buffer.data(), DWORD(buffer.size()), &count, nullptr)) {ok = false; break;}
        if (!count) break;
        ok = BCryptHashData(hash, buffer.data(), count, 0) >= 0;
    }
    std::array<unsigned char, 32> digest{};
    if (ok) ok = BCryptFinishHash(hash, digest.data(), DWORD(digest.size()), 0) >= 0;
    if (hash) BCryptDestroyHash(hash);
    if (algorithm) BCryptCloseAlgorithmProvider(algorithm, 0);
    CloseHandle(file);
    constexpr char hex[] = "0123456789ABCDEF";
    std::string encoded;
    for (auto byte : digest) {encoded += hex[byte >> 4]; encoded += hex[byte & 15];}
    return ok && encoded == "94C2EBD3CA9F4C4212898D727DF5482937F586771C67502635EBD4367422052A";
}

static void* address(const Lua& lua, int index) {
    return reinterpret_cast<void*>(static_cast<uintptr_t>(lua.get_integer(index)));
}

// Reflection-return sizes are checked before using the observed UE5.2 parameter
// layouts. FGeometry stays opaque; only FVector2D values are read/written.
static int geometry(const Lua& lua) {
    auto widget = address(lua, 1);
    auto get_geometry = address(lua, 1);
    auto slate = address(lua, 1);
    auto get_size = address(lua, 1);
    auto to_absolute = address(lua, 1);
    if (!widget || !get_geometry || !slate || !get_size || !to_absolute ||
        property_size(get_geometry) != 0x38 || return_offset(get_geometry) != 0 ||
        property_size(get_size) != 0x48 || return_offset(get_size) != 0x38 ||
        property_size(to_absolute) != 0x58 || return_offset(to_absolute) != 0x48) {
        lua.set_bool(false);
        std::string error = "Unsupported Slate reflection layout";
        if (get_geometry && get_size && to_absolute) {
            for (auto function : {get_geometry, get_size, to_absolute}) {
                error += " size=" + std::to_string(property_size(function)) +
                    ",return=" + std::to_string(return_offset(function));
            }
        }
        lua.set_string(error.c_str());
        return 2;
    }
    alignas(16) std::array<std::byte, 0x38> native_geometry{};
    process_event(widget, get_geometry, native_geometry.data());
    alignas(16) std::array<std::byte, 0x48> size_parameters{};
    std::memcpy(size_parameters.data(), native_geometry.data(), native_geometry.size());
    process_event(slate, get_size, size_parameters.data());
    std::array<double, 2> size{};
    std::memcpy(size.data(), size_parameters.data() + 0x38, sizeof(size));
    std::array<double, 4> corners{};
    for (int corner = 0; corner < 2; ++corner) {
        alignas(16) std::array<std::byte, 0x58> parameters{};
        std::memcpy(parameters.data(), native_geometry.data(), native_geometry.size());
        if (corner) std::memcpy(parameters.data() + 0x38, size.data(), sizeof(size));
        process_event(slate, to_absolute, parameters.data());
        std::memcpy(corners.data() + corner * 2, parameters.data() + 0x48, sizeof(size));
    }
    bool valid = size[0] > 0 && size[1] > 0;
    for (auto value : size) valid = valid && std::isfinite(value);
    for (auto value : corners) valid = valid && std::isfinite(value);
    if (!valid) {lua.set_bool(false); lua.set_string("Widget has no valid cached geometry"); return 2;}
    lua.set_bool(true);
    for (auto value : corners) lua.set_number(value);
    for (auto value : size) lua.set_number(value);
    return 7;
}

extern "C" __declspec(dllexport) int luaopen_mapteleport_native(lua_State* state) {
    HMODULE runtime = GetModuleHandleW(L"UE4SS.dll");
    if (!runtime || !qualified_runtime(runtime)) return 0;
    process_event = reinterpret_cast<ProcessEvent>(GetProcAddress(runtime,
        "?ProcessEvent@UObject@Unreal@RC@@QEAAXPEAVUFunction@23@PEAX@Z"));
    property_size = reinterpret_cast<PropertySize>(GetProcAddress(runtime,
        "?GetParmsSize@UFunction@Unreal@RC@@QEAAAEAGXZ"));
    return_offset = reinterpret_cast<ReturnOffset>(GetProcAddress(runtime,
        "?GetReturnValueOffset@UFunction@Unreal@RC@@QEAAAEAGXZ"));
    if (!process_event || !property_size || !return_offset) return 0;
    Lua lua(state);
    lua.register_function("MapTeleportNativeGeometry", geometry);
    lua.register_function("MapTeleportNativeGameWindow", game_window);
    lua.register_function("MapTeleportNativeArm", arm);
    lua.register_function("MapTeleportNativeDisarm", disarm);
    lua.register_function("MapTeleportNativePoll", poll);
    lua.register_function("MapTeleportNativeShutdown", shutdown);
    // UE4SS stores callbacks into this DLL. Keep code resident through process
    // lifetime, even if Lua releases the loadlib handle. Shutdown removes input.
    HMODULE pinned{};
    GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
        reinterpret_cast<LPCWSTR>(&luaopen_mapteleport_native), &pinned);
    return 0;
}
