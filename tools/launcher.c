// RAPTOR.app launcher for macOS
//
// A compiled Mach-O launcher that occupies Contents/MacOS/RAPTOR, so LaunchServices
// treats the bundle as a real application rather than a shell-script wrapper.
// It locates the system .NET 8 runtime, prepares the native library search path,
// then execs (not spawns) the runtime on raptor.dll.
//
// Why exec: RAPTOR here stays framework-dependent, since users must install the
// .NET 8 runtime anyway (that is the official requirement). Exec'ing keeps a
// single process and lets the bundle's Info.plist identity (icon, identifier)
// win over the generic `dotnet` host. Note that the application name Avalonia
// shows in-window is a hardcoded default inside Avalonia.Controls.dll and is
// NOT controlled by this launcher.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include <sys/stat.h>
#include <mach-o/dyld.h>

static int is_executable_file(const char *p) {
    struct stat st;
    if (stat(p, &st) != 0) return 0;
    return S_ISREG(st.st_mode) && (access(p, X_OK) == 0);
}

static int is_directory(const char *p) {
    struct stat st;
    return stat(p, &st) == 0 && S_ISDIR(st.st_mode);
}

// raptor.dll is data handed to the runtime, not something we exec ourselves.
static int is_readable_file(const char *p) {
    struct stat st;
    if (stat(p, &st) != 0) return 0;
    return S_ISREG(st.st_mode) && (access(p, R_OK) == 0);
}

// Join without overflowing; returns 0 on success.
static int join(char *out, size_t cap, const char *a, const char *b) {
    int n = snprintf(out, cap, "%s%s", a, b);
    return (n > 0 && (size_t)n < cap) ? 0 : -1;
}

int main(int argc, char *argv[]) {
    // Ask dyld for our own executable path, then resolve symlinks.
    char raw[PATH_MAX];
    uint32_t raw_size = sizeof(raw);
    if (_NSGetExecutablePath(raw, &raw_size) != 0) {
        fprintf(stderr, "RAPTOR: cannot resolve own path\n");
        return 1;
    }
    char exe[PATH_MAX];
    if (!realpath(raw, exe)) {
        snprintf(exe, sizeof(exe), "%s", raw);
    }

    // exe = .../RAPTOR.app/Contents/MacOS/RAPTOR
    // Strip "/MacOS/RAPTOR" twice to get ".../Contents"
    char *slash = strrchr(exe, '/');
    if (!slash) return 1;
    *slash = '\0';                    // .../Contents/MacOS
    slash = strrchr(exe, '/');
    if (!slash) return 1;
    *slash = '\0';                    // .../Contents

    char res[PATH_MAX], native_dir[PATH_MAX], dll[PATH_MAX];
    if (join(res, sizeof(res), exe, "/Resources") ||
        join(native_dir, sizeof(native_dir), res, "/runtimes/osx/native") ||
        join(dll, sizeof(dll), res, "/raptor.dll")) {
        fprintf(stderr, "RAPTOR: path too long\n");
        return 1;
    }

    // Fail early and legibly when this binary is not inside an intact bundle,
    // rather than reporting a confusing ".NET not found" error later.
    if (!is_directory(res) ||
        !is_directory(native_dir) ||
        !is_readable_file(dll)) {
        fprintf(stderr,
                "RAPTOR: bundle layout is incomplete.\n"
                "  expected: %s\n"
                "  missing raptor.dll or runtimes/osx/native\n"
                "Rebuild the app bundle with tools/package-macos.sh.\n", res);
        return 1;
    }

    // --- Locate the dotnet host -------------------------------------------
    const char *home = getenv("HOME");
    char home_candidate[PATH_MAX];
    home_candidate[0] = '\0';
    if (home) snprintf(home_candidate, sizeof(home_candidate), "%s/.dotnet/dotnet", home);

    const char *candidates[] = {
        "/usr/local/share/dotnet/dotnet",
        "/opt/homebrew/share/dotnet/dotnet",
        "/usr/local/bin/dotnet",
        "/opt/homebrew/bin/dotnet",
        home_candidate,
        NULL
    };

    char dotnet[PATH_MAX];
    dotnet[0] = '\0';
    for (int i = 0; candidates[i]; i++) {
        if (candidates[i][0] && is_executable_file(candidates[i])) {
            snprintf(dotnet, sizeof(dotnet), "%s", candidates[i]);
            break;
        }
    }
    if (dotnet[0] == '\0') {
        // Last resort: search PATH manually
        const char *path = getenv("PATH");
        if (path) {
            char *copy = strdup(path);
            if (copy) {
                for (char *tok = strtok(copy, ":"); tok; tok = strtok(NULL, ":")) {
                    char cand[PATH_MAX];
                    if (join(cand, sizeof(cand), tok, "/dotnet") == 0 && is_executable_file(cand)) {
                        snprintf(dotnet, sizeof(dotnet), "%s", cand);
                        break;
                    }
                }
                free(copy);
            }
        }
    }

    if (dotnet[0] == '\0') {
        const char *msg =
            "RAPTOR cannot start because the .NET 8.0 Runtime was not found.\\n\\n"
            "Install the macOS Arm64 Runtime from:\\n"
            "https://dotnet.microsoft.com/download/dotnet/8.0\\n\\n"
            "Then open RAPTOR again.";
        char cmd[4096];
        snprintf(cmd, sizeof(cmd),
                 "osascript -e 'display alert \"RAPTOR\" message \"%s\" as critical' "
                 ">/dev/null 2>&1", msg);
        if (system(cmd) != 0) {
            fprintf(stderr, "RAPTOR: .NET 8.0 Runtime not found.\n");
        }
        return 1;
    }

    // --- Environment -------------------------------------------------------
    // Native deps: libSkiaSharp / libHarfBuzzSharp / libAvaloniaNative / libgdiplus
    char dyld[PATH_MAX * 3];
    const char *old_dyld = getenv("DYLD_LIBRARY_PATH");
    snprintf(dyld, sizeof(dyld), "%s:%s%s%s", res, native_dir,
             (old_dyld && *old_dyld) ? ":" : "", (old_dyld && *old_dyld) ? old_dyld : "");
    setenv("DYLD_LIBRARY_PATH", dyld, 1);

    // Keep fontconfig and .NET caches inside the bundle instead of $HOME.
    char cache_dir[PATH_MAX];
    if (join(cache_dir, sizeof(cache_dir), exe, "/cache") == 0) {
        char fc_dir[PATH_MAX];
        if (join(fc_dir, sizeof(fc_dir), cache_dir, "/fontconfig") == 0) {
            mkdir(cache_dir, 0755);
            mkdir(fc_dir, 0755);
        }
        setenv("XDG_CACHE_HOME", cache_dir, 1);
    }
    setenv("DOTNET_CLI_TELEMETRY_OPTOUT", "1", 1);

    // Run from the Resources directory so relative asset paths resolve.
    if (chdir(res) != 0) {
        fprintf(stderr, "RAPTOR: cannot enter %s\n", res);
        return 1;
    }

    // --- Exec the runtime --------------------------------------------------
    char **child = calloc((size_t)argc + 3, sizeof(char *));
    if (!child) return 1;
    child[0] = dotnet;
    child[1] = dll;
    for (int i = 1; i < argc; i++) child[i + 1] = argv[i];
    child[argc + 1] = NULL;

    execv(dotnet, child);

    fprintf(stderr, "RAPTOR: failed to launch %s\n", dotnet);
    return 1;
}
