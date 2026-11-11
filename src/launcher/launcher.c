#include <windows.h>
#include <stdio.h>
#include <string.h>

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    char dirPath[MAX_PATH] = {0};
    GetModuleFileNameA(NULL, dirPath, MAX_PATH);
    
    // Obtener la carpeta donde reside este .exe
    char *lastSlash = strrchr(dirPath, '\\');
    if (lastSlash) {
        *lastSlash = '\0';
    }

    char godotExe[MAX_PATH] = {0};
    snprintf(godotExe, sizeof(godotExe), "%s\\bin\\Godot_v4.3-stable_win64.exe", dirPath);

    char altGodotExe[MAX_PATH] = {0};
    snprintf(altGodotExe, sizeof(altGodotExe), "%s\\bin\\godot.exe", dirPath);

    char selectedExe[MAX_PATH] = {0};

    // 1. Verificar si ya existe el runtime en bin/
    DWORD attr = GetFileAttributesA(godotExe);
    if (attr != INVALID_FILE_ATTRIBUTES && !(attr & FILE_ATTRIBUTE_DIRECTORY)) {
        strncpy(selectedExe, godotExe, sizeof(selectedExe) - 1);
    } else {
        attr = GetFileAttributesA(altGodotExe);
        if (attr != INVALID_FILE_ATTRIBUTES && !(attr & FILE_ATTRIBUTE_DIRECTORY)) {
            strncpy(selectedExe, altGodotExe, sizeof(selectedExe) - 1);
        }
    }

    // 2. Si no existe, invocar la configuración inicial
    if (strlen(selectedExe) == 0) {
        int resp = MessageBoxA(
            NULL,
            "Bienvenido a GenEffects Studio.\n\n"
            "Se ha detectado la primera ejecucion tras clonar el repositorio.\n"
            "Se descargara el runtime portable oficial de Godot 4.3 (~55 MB)\n"
            "para que puedas usar la herramienta al instante.\n\n"
            "¿Deseas continuar?",
            "GenEffects Studio - Instalacion Inicial",
            MB_YESNO | MB_ICONINFORMATION
        );

        if (resp != IDYES) {
            return 0;
        }

        // Ejecutar el descargador mostrando consola con barra de progreso
        char batPath[MAX_PATH] = {0};
        snprintf(batPath, sizeof(batPath), "%s\\Iniciar_GenEffects.bat", dirPath);

        char cmdLine[MAX_PATH * 2] = {0};
        snprintf(cmdLine, sizeof(cmdLine), "cmd.exe /c \"\"%s\"\"", batPath);

        STARTUPINFOA siBatch = { sizeof(siBatch) };
        PROCESS_INFORMATION piBatch;

        if (CreateProcessA(NULL, cmdLine, NULL, NULL, FALSE, 0, NULL, dirPath, &siBatch, &piBatch)) {
            WaitForSingleObject(piBatch.hProcess, INFINITE);
            CloseHandle(piBatch.hProcess);
            CloseHandle(piBatch.hThread);
        }

        // Volver a verificar si se descargo
        attr = GetFileAttributesA(godotExe);
        if (attr != INVALID_FILE_ATTRIBUTES && !(attr & FILE_ATTRIBUTE_DIRECTORY)) {
            strncpy(selectedExe, godotExe, sizeof(selectedExe) - 1);
        } else {
            attr = GetFileAttributesA(altGodotExe);
            if (attr != INVALID_FILE_ATTRIBUTES && !(attr & FILE_ATTRIBUTE_DIRECTORY)) {
                strncpy(selectedExe, altGodotExe, sizeof(selectedExe) - 1);
            }
        }

        if (strlen(selectedExe) == 0) {
            MessageBoxA(
                NULL,
                "No se pudo completar la instalacion automatica.\n"
                "Por favor, asegurate de tener conexion a internet o ejecuta Iniciar_GenEffects.bat directamente.",
                "Error - GenEffects Studio",
                MB_OK | MB_ICONERROR
            );
            return 1;
        }
    }

    // 3. Iniciar GenEffects Studio
    char launchCmd[MAX_PATH * 3] = {0};
    if (lpCmdLine && strlen(lpCmdLine) > 0) {
        snprintf(launchCmd, sizeof(launchCmd), "\"%s\" --path \"%s\" %s", selectedExe, dirPath, lpCmdLine);
    } else {
        snprintf(launchCmd, sizeof(launchCmd), "\"%s\" --path \"%s\"", selectedExe, dirPath);
    }

    STARTUPINFOA si = { sizeof(si) };
    PROCESS_INFORMATION pi;

    if (!CreateProcessA(NULL, launchCmd, NULL, NULL, FALSE, 0, NULL, dirPath, &si, &pi)) {
        char errBuf[256];
        snprintf(errBuf, sizeof(errBuf), "Error al iniciar GenEffects Studio (Codigo %lu).", GetLastError());
        MessageBoxA(NULL, errBuf, "Error de ejecucion", MB_OK | MB_ICONERROR);
        return 1;
    }

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return 0;
}
