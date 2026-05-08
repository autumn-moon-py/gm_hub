#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <appmodel.h>
#include <shellapi.h>
#include <shlobj.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {
constexpr wchar_t kProjectExtension[] = L".gmh";
constexpr wchar_t kProjectProgId[] = L"GMHub.Project";
constexpr wchar_t kProjectTypeName[] = L"GM Hub Project";

bool SetRegistryDefaultValue(HKEY root,
                             const std::wstring& subkey,
                             const std::wstring& value) {
  HKEY key = nullptr;
  const auto create_result =
      RegCreateKeyExW(root, subkey.c_str(), 0, nullptr, 0, KEY_SET_VALUE,
                      nullptr, &key, nullptr);
  if (create_result != ERROR_SUCCESS || key == nullptr) {
    return false;
  }
  const auto* data =
      reinterpret_cast<const BYTE*>(value.c_str());
  const DWORD size_in_bytes =
      static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t));
  const auto write_result =
      RegSetValueExW(key, nullptr, 0, REG_SZ, data, size_in_bytes);
  RegCloseKey(key);
  return write_result == ERROR_SUCCESS;
}

void RegisterProjectFileAssociation() {
  wchar_t module_path[MAX_PATH];
  const DWORD module_path_len =
      GetModuleFileNameW(nullptr, module_path, MAX_PATH);
  if (module_path_len == 0 || module_path_len == MAX_PATH) {
    return;
  }
  const std::wstring exe_path(module_path, module_path_len);
  const std::wstring open_command = L"\"" + exe_path + L"\" \"%1\"";
  const std::wstring default_icon = L"\"" + exe_path + L"\",0";

  const std::wstring classes_root = L"Software\\Classes\\";
  SetRegistryDefaultValue(HKEY_CURRENT_USER, classes_root + kProjectExtension,
                          kProjectProgId);
  SetRegistryDefaultValue(HKEY_CURRENT_USER, classes_root + kProjectProgId,
                          kProjectTypeName);
  SetRegistryDefaultValue(HKEY_CURRENT_USER,
                          classes_root + kProjectProgId + L"\\DefaultIcon",
                          default_icon);
  SetRegistryDefaultValue(
      HKEY_CURRENT_USER,
      classes_root + kProjectProgId + L"\\shell\\open\\command",
      open_command);
  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
}

bool IsRunningPackaged() {
  UINT32 package_full_name_length = 0;
  const LONG result =
      GetCurrentPackageFullName(&package_full_name_length, nullptr);
  return result != APPMODEL_ERROR_NO_PACKAGE;
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (!IsRunningPackaged()) {
    RegisterProjectFileAssociation();
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"gm_hub", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
