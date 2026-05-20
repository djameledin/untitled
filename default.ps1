$code = @"
using System;
using System.Runtime.InteropServices;

public class BSOD {
    [DllImport("ntdll.dll")]
    public static extern uint NtRaiseHardError(
        uint ErrorStatus,
        uint NumberOfParameters,
        uint UnicodeStringParameterMask,
        IntPtr Parameters,
        uint ValidResponseOptions,
        out uint Response
    );

    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern bool OpenProcessToken(
        IntPtr ProcessHandle,
        uint DesiredAccess,
        out IntPtr TokenHandle
    );

    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern bool LookupPrivilegeValue(
        string lpSystemName,
        string lpName,
        out long lpLuid
    );

    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern bool AdjustTokenPrivileges(
        IntPtr TokenHandle,
        bool DisableAllPrivileges,
        ref TOKEN_PRIVILEGES NewState,
        uint BufferLength,
        IntPtr PreviousState,
        IntPtr ReturnLength
    );

    [StructLayout(LayoutKind.Sequential)]
    public struct TOKEN_PRIVILEGES {
        public uint PrivilegeCount;
        public long Luid;
        public uint Attributes;
    }

    public static void Trigger() {
        IntPtr hToken;
        OpenProcessToken(
            System.Diagnostics.Process.GetCurrentProcess().Handle,
            0x0020 | 0x0008, out hToken
        );

        TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
        tp.PrivilegeCount = 1;
        tp.Attributes = 0x00000002;
        LookupPrivilegeValue(null, "SeShutdownPrivilege", out tp.Luid);
        AdjustTokenPrivileges(hToken, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);

        uint response;
        NtRaiseHardError(0xC000021A, 0, 0, IntPtr.Zero, 6, out response);
    }
}
"@

Add-Type -TypeDefinition $code
[BSOD]::Trigger()
